"""
Comprehensive unit tests for functions/task.py
Tests Task dataclass, issue reference handling, priority_needs_updated flag management,
ranker execution, asynchronous Firebase task_queue enqueuing, and decoupled forced reranking.
"""

import os
import sys
import unittest
from unittest.mock import ANY, MagicMock, patch

# Add functions to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "functions"))

from firebase_functions import tasks_fn
from queue_utils import _safe_run_worker, dispatch_task, is_emulator

import main
from genai_ranker import (
    TaskPriorityOutput,
    run_ranker,
)
from github_sync import IssuePayload
from task import (
    Task,
    cleanup_repo_tasks,
    delete_all_user_tasks,
    delete_task_for_issue,
    enqueue_task_ranking,
    ensure_task_for_issue,
    force_rerank_tasks,
    get_user_tasks,
    mark_all_tasks_for_reranking,
    update_task_priority,
)


def get_callable_handler(func):
    """Helper to extract the original callable / task handler function from Firebase decorators."""
    target = getattr(func, "__wrapped__", func)
    if hasattr(target, "__closure__") and target.__closure__:
        for cell in target.__closure__:
            if callable(cell.cell_contents) and not getattr(cell.cell_contents, "__closure__", None):
                return cell.cell_contents
    if hasattr(func, "__closure__") and func.__closure__:
        for cell in func.__closure__:
            if callable(cell.cell_contents) and not getattr(cell.cell_contents, "__closure__", None):
                return cell.cell_contents
    return target


class TestQueueUtils(unittest.TestCase):
    @patch.dict(os.environ, {"FUNCTIONS_EMULATOR": "true"}, clear=True)
    def test_is_emulator_functions_emulator(self):
        self.assertTrue(is_emulator())

    @patch.dict(os.environ, {"FIREBASE_EMULATOR_HUB": "127.0.0.1:4400"}, clear=True)
    def test_is_emulator_hub(self):
        self.assertTrue(is_emulator())

    @patch.dict(os.environ, {"FIRESTORE_EMULATOR_HOST": "127.0.0.1:8080"}, clear=True)
    def test_is_emulator_firestore_host(self):
        self.assertTrue(is_emulator())

    @patch.dict(os.environ, {}, clear=True)
    def test_is_emulator_false_in_production(self):
        self.assertFalse(is_emulator())

    @patch("queue_utils.is_emulator", return_value=True)
    @patch("queue_utils.threading.Thread")
    def test_dispatch_task_under_emulator(self, mock_thread_cls, mock_is_emu):
        mock_worker = MagicMock()
        mock_thread_instance = MagicMock()
        mock_thread_cls.return_value = mock_thread_instance

        dispatch_task(queue_name="test_queue", task_data={"foo": "bar"}, worker_fn=mock_worker)
        mock_thread_cls.assert_called_once()
        self.assertTrue(mock_thread_cls.call_args[1].get("daemon"))
        mock_thread_instance.start.assert_called_once()

    @patch("queue_utils.is_emulator", return_value=False)
    @patch("firebase_admin.functions.task_queue")
    def test_dispatch_task_production_success(self, mock_task_queue, mock_is_emu):
        mock_queue = MagicMock()
        mock_queue.enqueue.return_value = "prod_task_123"
        mock_task_queue.return_value = mock_queue

        mock_worker = MagicMock()
        dispatch_task(queue_name="prod_queue", task_data={"uid": "u1"}, worker_fn=mock_worker)
        mock_task_queue.assert_called_once_with("prod_queue")
        mock_queue.enqueue.assert_called_once()

    @patch("queue_utils.is_emulator", return_value=False)
    @patch("queue_utils.threading.Thread")
    @patch("firebase_admin.functions.task_queue")
    def test_dispatch_task_production_fallback(self, mock_task_queue, mock_thread_cls, mock_is_emu):
        mock_task_queue.side_effect = Exception("Cloud Tasks unavailable")
        mock_worker = MagicMock()
        mock_thread_instance = MagicMock()
        mock_thread_cls.return_value = mock_thread_instance

        dispatch_task(queue_name="fallback_queue", task_data={"uid": "u1"}, worker_fn=mock_worker)
        mock_thread_instance.start.assert_called_once()

    def test_safe_run_worker_handles_exception(self):
        def bad_worker():
            raise ValueError("Worker crash")

        # Must not raise
        _safe_run_worker(bad_worker)


class TestTaskModel(unittest.TestCase):
    def test_task_model_defaults_properties_and_json_serialization(self):
        task = Task(
            priority=0.85,
            priority_needs_updated=True,
            owner="owner",
            repo="repo",
            issue_number=1,
            github_issue_title="Fix high priority bug",
            github_issue_url="https://github.com/owner/repo/issues/1",
        )
        self.assertEqual(task.doc_id, "task_owner_repo_1")
        self.assertEqual(task.priority, 0.85)
        self.assertTrue(task.priority_needs_updated)
        self.assertEqual(task.owner, "owner")
        self.assertEqual(task.repo, "repo")
        self.assertEqual(task.issue_number, 1)

        # Test Pydantic JSON serialization
        json_str = task.model_dump_json()
        self.assertIn('"priority":0.85', json_str.replace(" ", ""))
        self.assertIn('"github_issue_title":"Fix high priority bug"', json_str)

        # Test dictionary conversion via model_dump
        dumped = task.model_dump()
        self.assertEqual(dumped["owner"], "owner")
        self.assertEqual(dumped["priority"], 0.85)
        self.assertTrue(dumped["priority_needs_updated"])
        self.assertEqual(dumped["github_issue_title"], "Fix high priority bug")
        self.assertEqual(dumped["github_issue_url"], "https://github.com/owner/repo/issues/1")

        # Test reconstruction via model_validate
        reconstructed = Task.model_validate(dumped)
        self.assertEqual(reconstructed.doc_id, task.doc_id)
        self.assertEqual(reconstructed.priority, 0.85)
        self.assertTrue(reconstructed.priority_needs_updated)

    def test_task_owner_repo_issue_number_fields(self):
        task = Task(
            owner="dart-lang",
            repo="http",
            issue_number=1956,
        )
        self.assertEqual(task.doc_id, "task_dart-lang_http_1956")
        self.assertEqual(task.owner, "dart-lang")
        self.assertEqual(task.repo, "http")
        self.assertEqual(task.issue_number, 1956)

        dumped = task.model_dump()
        self.assertEqual(dumped["owner"], "dart-lang")
        self.assertEqual(dumped["issue_number"], 1956)

    def test_task_timestamps_handling(self):
        from datetime import datetime, timezone

        now = datetime(2026, 8, 23, 10, 0, 0, tzinfo=timezone.utc)
        task = Task.model_validate(
            {
                "owner": "org",
                "repo": "repo",
                "issue_number": 1,
                "created_at": now.isoformat(),
                "updated_at": "2026-08-23T10:05:00Z",  # Pydantic string coercion
            }
        )
        self.assertEqual(task.created_at, now)
        self.assertIsInstance(task.updated_at, datetime)
        self.assertEqual(task.updated_at, datetime(2026, 8, 23, 10, 5, 0, tzinfo=timezone.utc))

        json_str = task.model_dump_json()
        self.assertIn('"created_at":"2026-08-23T10:00:00Z"', json_str.replace("+00:00", "Z"))


class TestRankerEngine(unittest.TestCase):
    def test_run_ranker_with_pydantic_ai_agent(self):
        mock_agent = MagicMock()
        mock_output = TaskPriorityOutput(
            priority=0.92, reasoning="Current user @brian is explicitly mentioned in comments asking for a blocker fix."
        )
        mock_res = MagicMock()
        mock_res.output = mock_output

        def fake_run_sync(user_prompt):
            self.assertIn("@brian", user_prompt)
            self.assertIn("Critical Blocker", user_prompt)
            self.assertIn("Hey @brian please check this ASAP", user_prompt)
            self.assertIn("18", user_prompt)
            return mock_res

        mock_agent.run_sync.side_effect = fake_run_sync

        task = Task(
            owner="owner",
            repo="repo",
            issue_number=1,
            priority=0.0,
            priority_needs_updated=True,
            github_issue_title="Critical Blocker",
        )
        issue_data = {
            "title": "Critical Blocker",
            "body": "System down due to null pointer.",
            "user": "alice",
            "upvotes": 18,
            "comments": [
                {
                    "user_login": "charlie",
                    "body": "Hey @brian please check this ASAP",
                    "created_at": "2026-08-22T12:00:00Z",
                }
            ],
        }

        ranked = run_ranker(
            task=task, issue=issue_data, github_username="brian", gemini_api_key="AIzaSyRankerKey", agent=mock_agent
        )
        self.assertEqual(ranked.priority, 0.92)
        self.assertFalse(ranked.priority_needs_updated)

    @patch("genai_ranker.genai.Client")
    @patch("genai_ranker.GoogleProvider")
    @patch("genai_ranker.GoogleModel")
    @patch("genai_ranker.Agent")
    def test_get_pydantic_ai_agent_uses_gemini_api_key(
        self, mock_agent_cls, mock_model_cls, mock_provider_cls, mock_client_cls
    ):
        from genai_ranker import get_pydantic_ai_agent

        mock_agent_instance = MagicMock()
        mock_agent_cls.return_value = mock_agent_instance

        agent = get_pydantic_ai_agent(api_key="custom_key_12345")
        mock_client_cls.assert_called_once()
        self.assertEqual(mock_client_cls.call_args[1].get("api_key"), "custom_key_12345")
        self.assertEqual(agent, mock_agent_instance)

    def test_run_ranker_raises_on_error(self):
        mock_agent = MagicMock()
        mock_agent.run_sync.side_effect = RuntimeError("Non-recoverable fatal error")

        task = Task(owner="owner", repo="repo", issue_number=1, priority=0.65, priority_needs_updated=True)
        with self.assertRaises(RuntimeError):
            run_ranker(task=task, gemini_api_key="bad_key", agent=mock_agent)


class TestTaskFirestoreOperations(unittest.TestCase):
    def test_ensure_task_for_issue_creation_and_update(self):
        mock_db = MagicMock()
        mock_user_doc = MagicMock()
        mock_tasks_col = MagicMock()
        mock_task_ref = MagicMock()
        mock_doc_snap = MagicMock()

        mock_db.collection.return_value.document.return_value = mock_user_doc
        mock_user_doc.collection.return_value = mock_tasks_col
        mock_tasks_col.document.return_value = mock_task_ref
        mock_task_ref.get.return_value = mock_doc_snap

        # Case 1: Task does not exist yet (brand new issue -> sets priority_needs_updated = True)
        mock_doc_snap.exists = False
        ensure_task_for_issue(
            uid="user_100",
            issue_id="org_repo_1",
            issue_data={
                "title": "Brand new issue",
                "url": "https://github.com/org/repo/issues/1",
                "owner": "org",
                "repo": "repo",
                "issue_number": 1,
            },
            db=mock_db,
        )
        mock_task_ref.set.assert_called_once()
        args, _ = mock_task_ref.set.call_args
        self.assertTrue(args[0]["priority_needs_updated"])
        self.assertEqual(args[0]["github_issue_title"], "Brand new issue")
        self.assertEqual(args[0]["github_issue_url"], "https://github.com/org/repo/issues/1")

        # Case 2: Task already exists (modified issue -> sets priority_needs_updated = True)
        mock_doc_snap.exists = True
        mock_doc_snap.to_dict.return_value = {
            "priority": 0.7,
            "priority_needs_updated": False,
            "owner": "org",
            "repo": "repo",
            "issue_number": 1,
            "github_issue_title": "Old title",
        }
        mock_task_ref.set.reset_mock()

        ensure_task_for_issue(
            uid="user_100",
            issue_id="org_repo_1",
            issue_data={"title": "Updated issue title", "url": "https://github.com/org/repo/issues/1"},
            db=mock_db,
        )
        mock_task_ref.set.assert_called_once()
        args, _ = mock_task_ref.set.call_args
        self.assertTrue(args[0]["priority_needs_updated"])
        self.assertEqual(args[0]["github_issue_title"], "Updated issue title")
        self.assertEqual(args[0]["priority"], 0.7)

    @patch("github_sync.fetch_issue_in_memory")
    @patch("task.run_ranker")
    def test_update_task_priority(self, mock_run_ranker, mock_fetch_in_memory):
        mock_db = MagicMock()
        mock_user_doc = MagicMock()
        mock_tasks_col = MagicMock()
        mock_task_ref = MagicMock()

        mock_task_snap = MagicMock()
        mock_task_snap.exists = True
        mock_task_snap.to_dict.return_value = {
            "owner": "org",
            "repo": "repo",
            "issue_number": 10,
            "priority": 0.0,
            "priority_needs_updated": True,
            "github_issue_title": "Needs rank",
        }
        mock_task_ref.get.return_value = mock_task_snap

        mock_in_memory_issue = IssuePayload(
            issue={"title": "Issue 10", "body": "Description"},
            comments=[{"user": {"login": "bob"}, "body": "Comment text"}],
        )
        mock_fetch_in_memory.return_value = mock_in_memory_issue

        mock_user_snap = MagicMock()
        mock_user_snap.exists = True
        mock_user_snap.to_dict.return_value = {
            "github_username": "brian_dev",
            "github_access_token": "ghp_valid_token_123",
            "gemini_api_key": "AIzaSyUserDocKey",
        }
        mock_user_doc.get.return_value = mock_user_snap

        mock_user_doc.collection.return_value = mock_tasks_col
        mock_tasks_col.document.return_value = mock_task_ref
        mock_db.collection.return_value.document.return_value = mock_user_doc

        ranked_mock_task = Task(owner="org", repo="repo", issue_number=10, priority=0.88, priority_needs_updated=False)
        mock_run_ranker.return_value = ranked_mock_task

        update_task_priority("user_100", "task_issue_10", mock_db)
        mock_fetch_in_memory.assert_called_once_with(
            access_token="ghp_valid_token_123",
            owner="org",
            repo="repo",
            issue_number=10,
        )
        mock_run_ranker.assert_called_once()
        _args, kwargs = mock_run_ranker.call_args
        self.assertEqual(kwargs.get("github_username"), "brian_dev")
        self.assertEqual(kwargs.get("gemini_api_key"), "AIzaSyUserDocKey")
        self.assertEqual(kwargs.get("issue"), mock_in_memory_issue)
        mock_task_ref.set.assert_called_once()
        args, _ = mock_task_ref.set.call_args
        self.assertEqual(args[0]["priority"], 0.88)
        self.assertFalse(args[0]["priority_needs_updated"])

    def test_force_rerank_tasks_marks(self):
        mock_db = MagicMock()
        mock_user_doc = MagicMock()
        mock_tasks_col = MagicMock()
        mock_batch = MagicMock()

        mock_db.collection.return_value.document.return_value = mock_user_doc
        mock_user_doc.collection.return_value = mock_tasks_col
        mock_db.batch.return_value = mock_batch

        mock_doc1 = MagicMock()
        mock_doc1.id = "task_1"
        mock_doc1.to_dict.return_value = {"id": "task_1", "priority": 0.5, "priority_needs_updated": False}
        mock_tasks_col.stream.return_value = [mock_doc1]

        result = force_rerank_tasks("user_100", mock_db)
        self.assertEqual(result["status"], "marked")
        self.assertEqual(result["marked_count"], 1)
        mock_batch.commit.assert_called_once()

    @patch("queue_utils.is_emulator", return_value=False)
    @patch("firebase_admin.functions.task_queue")
    def test_enqueue_task_ranking_with_firebase_admin(self, mock_task_queue, mock_is_emu):
        mock_queue = MagicMock()
        mock_queue.enqueue.return_value = "task_id_xyz_123"
        mock_task_queue.return_value = mock_queue

        mock_db = MagicMock()
        enqueue_task_ranking(uid="user_task_queue_1", task_id="task_abc_1", db=mock_db, function_name="rank_user_tasks")
        mock_task_queue.assert_called_once_with("rank_user_tasks")
        mock_queue.enqueue.assert_called_once()
        args, _kwargs = mock_queue.enqueue.call_args
        self.assertEqual(args[0], {"uid": "user_task_queue_1", "task_id": "task_abc_1"})

    @patch("queue_utils.is_emulator", return_value=True)
    @patch("queue_utils.threading.Thread")
    def test_enqueue_task_ranking_fallback_dispatch(self, mock_thread_cls, mock_is_emu):
        mock_db = MagicMock()
        mock_thread_instance = MagicMock()
        mock_thread_cls.return_value = mock_thread_instance

        enqueue_task_ranking(uid="user_async_1", task_id="task_fallback_1", db=mock_db)
        mock_thread_instance.start.assert_called_once()

    def test_get_user_tasks_sorted_by_priority(self):
        mock_db = MagicMock()
        mock_user_doc = MagicMock()
        mock_tasks_col = MagicMock()

        mock_db.collection.return_value.document.return_value = mock_user_doc
        mock_user_doc.collection.return_value = mock_tasks_col

        doc_low = MagicMock()
        doc_low.id = "task_low"
        doc_low.to_dict.return_value = {"id": "task_low", "priority": 0.2, "priority_needs_updated": False}

        doc_high = MagicMock()
        doc_high.id = "task_high"
        doc_high.to_dict.return_value = {"id": "task_high", "priority": 0.9, "priority_needs_updated": False}

        mock_tasks_col.limit.return_value.stream.return_value = [doc_low, doc_high]

        tasks = get_user_tasks("user_100", mock_db)
        self.assertEqual(len(tasks), 2)
        self.assertEqual(tasks[0]["id"], "task_high")
        self.assertEqual(tasks[1]["id"], "task_low")


class TestTaskQueueFunction(unittest.TestCase):
    @patch("main.update_task_priority")
    @patch("main.db")
    def test_rank_user_tasks_task_queue_handler(self, mock_db, mock_update_fn):
        handler = get_callable_handler(main.rank_user_tasks)

        mock_req = MagicMock(spec=tasks_fn.CallableRequest)
        mock_req.data = {"uid": "user_queue_001", "task_id": "task_queue_001"}

        result = handler(mock_req)
        self.assertIsNone(result)
        mock_update_fn.assert_called_once_with(uid="user_queue_001", task_id="task_queue_001", db=mock_db)

    def test_rank_user_tasks_missing_uid_raises_error(self):
        handler = get_callable_handler(main.rank_user_tasks)
        mock_req = MagicMock(spec=tasks_fn.CallableRequest)
        mock_req.data = {"task_id": "task_1"}

        with self.assertRaises(tasks_fn.HttpsError) as ctx:
            handler(mock_req)
        self.assertEqual(ctx.exception.code, tasks_fn.FunctionsErrorCode.INVALID_ARGUMENT)

    def test_rank_user_tasks_missing_task_id_raises_error(self):
        handler = get_callable_handler(main.rank_user_tasks)
        mock_req = MagicMock(spec=tasks_fn.CallableRequest)
        mock_req.data = {"uid": "user_1"}

        with self.assertRaises(tasks_fn.HttpsError) as ctx:
            handler(mock_req)
        self.assertEqual(ctx.exception.code, tasks_fn.FunctionsErrorCode.INVALID_ARGUMENT)


class TestTaskLifecycleAndSourceTracking(unittest.TestCase):
    def test_ensure_task_for_issue_tracks_sources(self):
        mock_db = MagicMock()
        mock_user_doc = MagicMock()
        mock_tasks_col = MagicMock()
        mock_task_ref = MagicMock()
        mock_doc_snap = MagicMock()

        mock_db.collection.return_value.document.return_value = mock_user_doc
        mock_user_doc.collection.return_value = mock_tasks_col
        mock_tasks_col.document.return_value = mock_task_ref
        mock_task_ref.get.return_value = mock_doc_snap

        # Case 1: Initial creation with source 'assigned'
        mock_doc_snap.exists = False
        ensure_task_for_issue(
            uid="user_src_1",
            issue_id="org_repo_1",
            issue_data={"title": "Issue", "url": "https://url", "owner": "org", "repo": "repo", "issue_number": 1},
            db=mock_db,
            source="assigned",
        )
        call_args, _ = mock_task_ref.set.call_args
        self.assertEqual(call_args[0]["sources"], ["assigned"])

        # Case 2: Subsequent update adds source 'monitored'
        mock_doc_snap.exists = True
        mock_doc_snap.to_dict.return_value = {
            "owner": "org",
            "repo": "repo",
            "issue_number": 1,
            "sources": ["assigned"],
        }
        ensure_task_for_issue(
            uid="user_src_1",
            issue_id="org_repo_1",
            issue_data={"title": "Issue", "url": "https://url", "owner": "org", "repo": "repo", "issue_number": 1},
            db=mock_db,
            source="monitored",
        )
        call_args, _ = mock_task_ref.set.call_args
        self.assertEqual(sorted(call_args[0]["sources"]), ["assigned", "monitored"])

    def test_delete_all_user_tasks(self):
        mock_db = MagicMock()
        mock_tasks_col = MagicMock()
        mock_batch = MagicMock()
        mock_db.collection.return_value.document.return_value.collection.return_value = mock_tasks_col
        mock_db.batch.return_value = mock_batch

        doc1 = MagicMock()
        doc2 = MagicMock()
        mock_tasks_col.stream.return_value = [doc1, doc2]

        deleted_count = delete_all_user_tasks("user_del_1", mock_db)
        self.assertEqual(deleted_count, 2)
        mock_batch.delete.assert_any_call(doc1.reference)
        mock_batch.delete.assert_any_call(doc2.reference)
        mock_batch.commit.assert_called_once()

    def test_delete_task_for_issue(self):
        mock_db = MagicMock()
        mock_task_ref = MagicMock()
        mock_doc_snap = MagicMock()
        mock_db.collection.return_value.document.return_value.collection.return_value.document.return_value = (
            mock_task_ref
        )
        mock_task_ref.get.return_value = mock_doc_snap

        # Exists -> deletes and returns True
        mock_doc_snap.exists = True
        res = delete_task_for_issue("user_1", "org_repo_1", mock_db)
        self.assertTrue(res)
        mock_task_ref.delete.assert_called_once()

        # Does not exist -> returns False
        mock_doc_snap.exists = False
        mock_task_ref.delete.reset_mock()
        res = delete_task_for_issue("user_1", "org_repo_2", mock_db)
        self.assertFalse(res)
        mock_task_ref.delete.assert_not_called()

    def test_mark_all_tasks_for_reranking(self):
        mock_db = MagicMock()
        mock_user_doc = MagicMock()
        mock_tasks_col = MagicMock()
        mock_batch = MagicMock()

        mock_db.collection.return_value.document.return_value = mock_user_doc
        mock_user_doc.collection.return_value = mock_tasks_col
        mock_db.batch.return_value = mock_batch

        doc1 = MagicMock()
        doc1.id = "task_doc_1"
        mock_tasks_col.stream.return_value = [doc1]

        count = mark_all_tasks_for_reranking("user_rerank_1", mock_db)
        self.assertEqual(count, 1)
        mock_batch.set.assert_called_once_with(
            doc1.reference,
            {"priority_needs_updated": True, "updated_at": ANY},
            merge=True,
        )
        mock_batch.commit.assert_called_once()

    def test_mark_all_tasks_for_reranking_chunks_over_450(self):
        mock_db = MagicMock()
        mock_user_doc = MagicMock()
        mock_tasks_col = MagicMock()
        mock_batch1 = MagicMock()
        mock_batch2 = MagicMock()

        mock_db.collection.return_value.document.return_value = mock_user_doc
        mock_user_doc.collection.return_value = mock_tasks_col
        mock_db.batch.side_effect = [mock_batch1, mock_batch2]

        docs = [MagicMock() for _ in range(500)]
        mock_tasks_col.stream.return_value = docs

        count = mark_all_tasks_for_reranking("user_chunks", mock_db)
        self.assertEqual(count, 500)
        self.assertEqual(mock_batch1.commit.call_count, 1)
        self.assertEqual(mock_batch2.commit.call_count, 1)

    def test_cleanup_repo_tasks_deletes_monitored_only_tasks(self):
        mock_db = MagicMock()
        mock_tasks_col = MagicMock()
        mock_db.collection.return_value.document.return_value.collection.return_value = mock_tasks_col

        # Task 1: Only from monitored repo -> should be deleted
        doc1 = MagicMock()
        doc1.to_dict.return_value = {
            "owner": "org",
            "repo": "repo1",
            "issue_number": 1,
            "sources": ["monitored"],
        }

        # Task 2: From monitored repo AND assigned -> should be preserved with 'monitored' removed
        doc2 = MagicMock()
        doc2.to_dict.return_value = {
            "owner": "org",
            "repo": "repo1",
            "issue_number": 2,
            "sources": ["assigned", "monitored"],
        }

        # Task 3: Different repo -> untouched
        doc3 = MagicMock()
        doc3.to_dict.return_value = {
            "owner": "other",
            "repo": "other_repo",
            "issue_number": 3,
            "sources": ["monitored"],
        }

        mock_tasks_col.stream.return_value = [doc1, doc2, doc3]

        cleanup_repo_tasks(uid="user_cleanup_1", repo_full_name="org/repo1", db=mock_db)
        doc1.reference.delete.assert_called_once()
        doc2.reference.set.assert_called_once_with({"sources": ["assigned"], "updated_at": ANY}, merge=True)
        doc3.reference.delete.assert_not_called()
        doc3.reference.set.assert_not_called()

    def test_task_thumbs_down_at_fields(self):
        from datetime import datetime, timezone

        t_down = datetime(2026, 9, 4, 15, 0, 0, tzinfo=timezone.utc)
        gh_up = datetime(2026, 9, 4, 16, 0, 0, tzinfo=timezone.utc)
        task = Task(
            owner="org",
            repo="repo",
            issue_number=42,
            priority=0.0,
            priority_needs_updated=False,
            thumbs_down_at=t_down,
            github_updated_at=gh_up,
        )
        self.assertEqual(task.thumbs_down_at, t_down)
        self.assertEqual(task.github_updated_at, gh_up)
        dumped = task.model_dump()
        self.assertEqual(dumped["thumbs_down_at"], t_down)
        self.assertEqual(dumped["github_updated_at"], gh_up)

    def test_ensure_task_for_issue_suppresses_rerank_when_not_updated_after_thumbs_down(self):
        from datetime import datetime, timezone

        mock_db = MagicMock()
        mock_task_ref = MagicMock()
        mock_tasks_col = MagicMock()
        mock_tasks_col.document.return_value = mock_task_ref
        mock_db.collection.return_value.document.return_value.collection.return_value = mock_tasks_col

        t_down = datetime(2026, 9, 4, 15, 0, 0, tzinfo=timezone.utc)
        gh_up_old = datetime(2026, 9, 4, 14, 0, 0, tzinfo=timezone.utc)

        mock_task_snap = MagicMock()
        mock_task_snap.exists = True
        mock_task_snap.to_dict.return_value = {
            "owner": "org",
            "repo": "repo",
            "issue_number": 42,
            "priority": 0.0,
            "priority_needs_updated": False,
            "thumbs_down_at": t_down,
            "github_updated_at": gh_up_old,
        }
        mock_task_ref.get.return_value = mock_task_snap

        ensure_task_for_issue(
            uid="user_100",
            issue_id="org_repo_42",
            issue_data={
                "title": "Unchanged Issue",
                "github_updated_at": gh_up_old,
            },
            db=mock_db,
        )
        mock_task_ref.set.assert_called_once()
        args, _ = mock_task_ref.set.call_args
        # Should NOT trigger rerank; priority should remain 0.0
        self.assertFalse(args[0]["priority_needs_updated"])
        self.assertEqual(args[0]["priority"], 0.0)

    def test_ensure_task_for_issue_triggers_rerank_when_updated_after_thumbs_down(self):
        from datetime import datetime, timezone

        mock_db = MagicMock()
        mock_task_ref = MagicMock()
        mock_tasks_col = MagicMock()
        mock_tasks_col.document.return_value = mock_task_ref
        mock_db.collection.return_value.document.return_value.collection.return_value = mock_tasks_col

        t_down = datetime(2026, 9, 4, 15, 0, 0, tzinfo=timezone.utc)
        gh_up_new = datetime(2026, 9, 4, 16, 0, 0, tzinfo=timezone.utc)

        mock_task_snap = MagicMock()
        mock_task_snap.exists = True
        mock_task_snap.to_dict.return_value = {
            "owner": "org",
            "repo": "repo",
            "issue_number": 42,
            "priority": 0.0,
            "priority_needs_updated": False,
            "thumbs_down_at": t_down,
            "github_updated_at": t_down,
        }
        mock_task_ref.get.return_value = mock_task_snap

        ensure_task_for_issue(
            uid="user_100",
            issue_id="org_repo_42",
            issue_data={
                "title": "Updated Issue",
                "github_updated_at": gh_up_new,
            },
            db=mock_db,
        )
        mock_task_ref.set.assert_called_once()
        args, _ = mock_task_ref.set.call_args
        # Should trigger rerank because gh_up_new > t_down
        self.assertTrue(args[0]["priority_needs_updated"])

    @patch("github_sync.fetch_issue_in_memory")
    @patch("task.run_ranker")
    def test_update_task_priority_propagates_thumbs_down_at_to_issue_payload(
        self, mock_run_ranker, mock_fetch_in_memory
    ):
        from datetime import datetime, timezone

        mock_db = MagicMock()
        mock_user_doc = MagicMock()
        mock_tasks_col = MagicMock()
        mock_task_ref = MagicMock()

        t_down = datetime(2026, 9, 4, 15, 0, 0, tzinfo=timezone.utc)

        mock_task_snap = MagicMock()
        mock_task_snap.exists = True
        mock_task_snap.to_dict.return_value = {
            "owner": "org",
            "repo": "repo",
            "issue_number": 42,
            "priority": 0.0,
            "priority_needs_updated": True,
            "thumbs_down_at": t_down,
        }
        mock_task_ref.get.return_value = mock_task_snap

        mock_in_memory_issue = IssuePayload(
            issue={"title": "Issue 42", "body": "Body"},
            comments=[],
        )
        mock_fetch_in_memory.return_value = mock_in_memory_issue

        mock_user_snap = MagicMock()
        mock_user_snap.exists = True
        mock_user_snap.to_dict.return_value = {
            "github_username": "brian_dev",
            "github_access_token": "ghp_valid_token_123",
            "gemini_api_key": "AIzaSyUserDocKey",
        }
        mock_user_doc.get.return_value = mock_user_snap

        mock_user_doc.collection.return_value = mock_tasks_col
        mock_tasks_col.document.return_value = mock_task_ref
        mock_db.collection.return_value.document.return_value = mock_user_doc

        ranked_mock_task = Task(owner="org", repo="repo", issue_number=42, priority=0.0, priority_needs_updated=False)
        mock_run_ranker.return_value = ranked_mock_task

        update_task_priority("user_100", "task_issue_42", mock_db)
        mock_run_ranker.assert_called_once()
        _args, kwargs = mock_run_ranker.call_args
        issue_arg = kwargs.get("issue")
        self.assertEqual(issue_arg.thumbs_down_at, t_down)


class TestUtcStandardization(unittest.TestCase):
    def test_to_utc_datetime_helper(self):
        from datetime import datetime, timedelta, timezone

        from task import to_utc_datetime

        # 1. Naive datetime -> aware UTC
        naive_dt = datetime(2026, 9, 5, 12, 0, 0)
        utc_dt = to_utc_datetime(naive_dt)
        self.assertIsNotNone(utc_dt)
        self.assertEqual(utc_dt.tzinfo, timezone.utc)
        self.assertEqual(utc_dt, datetime(2026, 9, 5, 12, 0, 0, tzinfo=timezone.utc))

        # 2. Offset-aware non-UTC datetime -> converted to UTC
        tz_offset = timezone(timedelta(hours=-5))
        offset_dt = datetime(2026, 9, 5, 12, 0, 0, tzinfo=tz_offset)
        converted = to_utc_datetime(offset_dt)
        self.assertIsNotNone(converted)
        self.assertEqual(converted.tzinfo, timezone.utc)
        self.assertEqual(converted, datetime(2026, 9, 5, 17, 0, 0, tzinfo=timezone.utc))

        # 3. ISO-8601 strings
        iso_z = to_utc_datetime("2026-09-05T12:00:00Z")
        self.assertEqual(iso_z, datetime(2026, 9, 5, 12, 0, 0, tzinfo=timezone.utc))

        iso_offset = to_utc_datetime("2026-09-05T12:00:00-04:00")
        self.assertEqual(iso_offset, datetime(2026, 9, 5, 16, 0, 0, tzinfo=timezone.utc))

        # 4. Invalid or None
        self.assertNull_or_none = self.assertIsNone(to_utc_datetime(None))
        self.assertIsNone(to_utc_datetime(""))
        self.assertIsNone(to_utc_datetime("not-a-datetime"))

    def test_task_model_normalizes_all_timestamps_to_utc(self):
        from datetime import datetime, timedelta, timezone

        # Provide naive datetimes
        naive_1 = datetime(2026, 9, 5, 10, 0, 0)
        naive_2 = datetime(2026, 9, 5, 11, 0, 0)
        offset_3 = datetime(2026, 9, 5, 8, 0, 0, tzinfo=timezone(timedelta(hours=-4)))

        task = Task(
            owner="org",
            repo="repo",
            issue_number=1,
            created_at=naive_1,
            updated_at=naive_2,
            thumbs_down_at=naive_1,
            github_updated_at=offset_3,
        )

        for field_name in ("created_at", "updated_at", "thumbs_down_at", "github_updated_at"):
            val = getattr(task, field_name)
            self.assertIsNotNone(val)
            self.assertEqual(val.tzinfo, timezone.utc)

        # Direct comparison must succeed without TypeError: can't compare offset-naive and offset-aware
        self.assertGreater(task.github_updated_at, task.thumbs_down_at)

    def test_user_model_normalizes_timestamps_to_utc(self):
        from datetime import datetime, timezone

        from user import User

        naive_sync = datetime(2026, 9, 5, 9, 30, 0)
        user = User(
            uid="user_123",
            last_assigned_sync=naive_sync,
            last_mentioned_sync=naive_sync,
            last_created_sync=naive_sync,
            monitored_repos={"brian/repo": naive_sync},
        )

        self.assertEqual(user.last_assigned_sync.tzinfo, timezone.utc)
        self.assertEqual(user.last_mentioned_sync.tzinfo, timezone.utc)
        self.assertEqual(user.last_created_sync.tzinfo, timezone.utc)
        self.assertEqual(user.monitored_repos["brian/repo"].tzinfo, timezone.utc)

    def test_issue_payload_normalizes_thumbs_down_at_to_utc(self):
        from datetime import datetime, timezone

        naive_down = datetime(2026, 9, 5, 14, 0, 0)
        payload = IssuePayload(
            issue={"title": "Test Issue"},
            comments=[],
            thumbs_down_at=naive_down,
        )
        self.assertEqual(payload.thumbs_down_at.tzinfo, timezone.utc)
        self.assertEqual(payload.thumbs_down_at, datetime(2026, 9, 5, 14, 0, 0, tzinfo=timezone.utc))


if __name__ == "__main__":
    unittest.main(verbosity=2)
