#!/usr/bin/env python3
"""
Run the mock-domain task set through the Koru gate, CAPTURING A PER-TASK
TRAJECTORY: every line the model emitted, the gate's verbatim verdict, and
the resulting conversation. Writes one readable text file per task under
bench/results/trajectories/.

The point is not a score. The point is the WHY: given the rule each task
encodes (policy.md), where did the model's behaviour diverge, and did the
gate catch it, teach it, or let it burn a turn?

  python3 bench/run_mock_traj.py [task_id ...] [--llm openrouter/...]
  python3 bench/run_mock_traj.py            # all ten mock tasks
"""

from __future__ import annotations

import sys
from pathlib import Path

from tau2.data_model.message import (  # noqa: F401
    AssistantMessage,
    ToolMessage,
    UserMessage,
)
from tau2.orchestrator.orchestrator import Orchestrator
from tau2.runner import build_environment, build_user, get_tasks, run_simulation
from tau2.evaluator.evaluator import EvaluationType

from kopium_agent import KopiumAgent, DomainConfig, _SPOKEN
from model_guard import guard_llm

HERE = Path(__file__).parent
GATE = HERE / "mock-gate-binary"
OUT = HERE / "results" / "trajectories"


class RecordingAgent(KopiumAgent):
    """KopiumAgent that records every gate call (model line + verdict) and
    every assistant/spoken emission into a per-task list."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.trace: list[str] = []

    def _gate(self, source: str) -> tuple[str, str]:
        status, detail = super()._gate(source)
        self.trace.append(f"  [gate] {source!r}\n         -> {status} {detail}")
        return status, detail

    def _render_values(self, messages) -> None:
        for i, msg in enumerate(messages):
            role = getattr(msg, "role", None)
            role_s = role.value if hasattr(role, "value") else str(role)
            tcs = getattr(msg, "tool_calls", None) or []
            content = getattr(msg, "content", None)
            if tcs:
                for tc in tcs:
                    self.trace.append(
                        f"  [{role_s}:{i}] TOOL CALL {tc.name}({json_dumps(tc.arguments)})"
                    )
            elif content:
                self.trace.append(f"  [{role_s}:{i}] {str(content)}")
            else:
                self.trace.append(f"  [{role_s}:{i}] (empty)")

    def generate_next_message(self, message, state):
        self.trace.append(f"  >>> user/tool input: {render_message(message)}")
        out, new_state = super().generate_next_message(message, state)
        self.trace.append(f"  <<< assistant {state_label(out)}")
        return out, new_state


def render_message(msg) -> str:
    tcs = getattr(msg, "tool_calls", None) or []
    if tcs:
        return "; ".join(f"{tc.name}({json_dumps(tc.arguments)})" for tc in tcs)
    content = getattr(msg, "content", None)
    return (str(content) if content else "(empty)")[:400]


def state_label(msg) -> str:
    tcs = getattr(msg, "tool_calls", None) or []
    if tcs:
        return "TOOL CALL " + "; ".join(
            f"{tc.name}({json_dumps(tc.arguments)})" for tc in tcs
        )
    content = getattr(msg, "content", None)
    return f"say/text: {(str(content) if content else '(empty)')[:120]}"


def json_dumps(args) -> str:
    import json

    try:
        return json.dumps(args, ensure_ascii=False) if not isinstance(args, str) else args
    except Exception:
        return str(args)


def main() -> None:
    llm = "unset/no-default-model"
    if "--llm" in sys.argv:
        llm = sys.argv[sys.argv.index("--llm") + 1]
    llm = guard_llm(llm)

    args = [a for a in sys.argv[1:] if a != "--llm"]
    if args:
        task_ids = args
    else:
        task_ids = [t.id for t in get_tasks("mock")]

    if not GATE.exists():
        sys.exit(f"gate binary missing: cd {HERE} && koruc mock-gate.k")
    OUT.mkdir(parents=True, exist_ok=True)

    # The domain policy is the lesson set — record it once at the top of each
    # trace so the trajectory can be read against the rule the task encodes.
    env0 = build_environment("mock")
    policy = env0.get_policy()

    for tid in task_ids:
        env = build_environment("mock")
        tasks = get_tasks("mock", task_ids=[tid])
        if not tasks:
            print(f"{tid}: NO SUCH TASK")
            continue
        task = tasks[0]
        agent = RecordingAgent(
            tools=env.get_tools(),
            domain_policy=env.get_policy(),
            domain="mock", gate_binary=GATE,
            llm=llm,
        )
        user = build_user("user_simulator", env, task, llm=llm)
        orch = Orchestrator(
            domain="mock",
            agent=agent,
            user=user,
            environment=env,
            task=task,
            max_steps=20,
            max_errors=5,
            seed=42,
        )
        try:
            res = run_simulation(orch, evaluation_type=EvaluationType.ALL)
            reward = res.reward_info.reward
            db = getattr(res.reward_info, "db_check", None)
            dbok = bool(db and db.db_match) if db else None
            basis = None
            basis_info = ""
            if getattr(res.reward_info, "reward_basis", None):
                b = res.reward_info.reward_basis
                basis = getattr(b, "value", None) or str(b)
            if getattr(res.reward_info, "info", None):
                try:
                    basis_info = str(res.reward_info.info)[:300]
                except Exception:
                    basis_info = ""
            term_reason = None
            if getattr(res, "termination_reason", None) is not None:
                tr = res.termination_reason
                term_reason = getattr(tr, "value", None) or str(tr)
        except Exception as e:  # noqa: BLE001
            reward = f"ERROR {type(e).__name__}: {str(e)[:80]}"
            dbok = None
            res = None
            basis = basis_info = term_reason = None

        lines = []
        lines.append(f"TASK      : {tid}")
        lines.append(f"INSTR     : {task.user_scenario.instructions}")
        lines.append(f"REWARD    : {reward}")
        lines.append(f"DB_MATCH  : {dbok}")
        lines.append(f"REWARD_BASIS: {basis}")
        lines.append(f"BASIS_INFO: {basis_info}")
        lines.append(f"TERMINATION: {term_reason}")
        lines.append(f"CALLS     : {getattr(agent, 'call_count', '?')}")
        lines.append(f"LLM       : {llm}")
        lines.append("")
        lines.append("=== POLICY (the lessons) ===")
        lines.append(policy)
        lines.append("")
        lines.append("=== TRAJECTORY ===")
        lines.extend(agent.trace)
        if res is not None:
            # final DB state, after the sim, as the ground truth the evaluator saw
            lines.append("")
            lines.append("=== MESSAGES ===")
            for i, msg in enumerate(res.messages):
                lines.append(render_message_full(i, msg))

        out_p = OUT / f"{tid}.txt"
        out_p.write_text("\n".join(lines) + "\n")
        print(f"{tid:40s} reward={reward} db={dbok} calls={getattr(agent,'call_count','?')} -> {out_p.name}")


def render_message_full(i: int, msg) -> str:
    tcs = getattr(msg, "tool_calls", None) or []
    role = getattr(msg, "role", None)
    role_s = role.value if hasattr(role, "value") else str(role)
    if tcs:
        return f"[{i}] {role_s} TOOL: " + "; ".join(
            f"{tc.name}({json_dumps(tc.arguments)})" for tc in tcs
        )
    content = str(getattr(msg, "content", None) or "")
    return f"[{i}] {role_s}: {content[:500]}"


if __name__ == "__main__":
    main()