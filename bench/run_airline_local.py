#!/usr/bin/env python3
"""Run the airline domain with the LOCAL LLaDA2.2 agent on the REAL gate.

AirlineLladaAgent + TauGateSession(airline-gate-binary): the gate emits
tool calls and blocks for results — the KOPIUM architecture end to end.
User sim still hosted; agent fully local.

  python3 bench/run_airline_local.py [task_id] [--arm warm|base]
        [--draft PATH] [--draft-frac F] [--steps N] [--llm MODEL]
"""

from __future__ import annotations

import sys
from pathlib import Path

from tau2.orchestrator.orchestrator import Orchestrator
from tau2.runner import build_environment, build_user, get_tasks, run_simulation
from tau2.evaluator.evaluator import EvaluationType

from airline_llada_agent import AirlineLladaAgent
from model_guard import guard_llm
from runlog import RunLogger, slug

HERE = Path(__file__).parent
GATE = HERE / "airline-gate-binary"


def main() -> None:
    task_id = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else "14"
    arm, steps, draft, construct, draft_frac, llm = "base", 16, None, None, 0.5, "unset/no-default-model"
    max_tokens = 512
    draft_blocks = 0
    temperature = 0.0
    retry_temperature = 0.0
    blank_values = False
    noise_draft = False
    trial = 0
    for i, a in enumerate(sys.argv):
        if a == "--arm" and i + 1 < len(sys.argv): arm = sys.argv[i + 1]
        elif a == "--steps" and i + 1 < len(sys.argv): steps = int(sys.argv[i + 1])
        elif a == "--draft" and i + 1 < len(sys.argv): draft = sys.argv[i + 1]
        elif a == "--construct" and i + 1 < len(sys.argv): construct = sys.argv[i + 1]
        elif a == "--draft-frac" and i + 1 < len(sys.argv): draft_frac = float(sys.argv[i + 1])
        elif a == "--llm" and i + 1 < len(sys.argv): llm = sys.argv[i + 1]
        elif a == "--max-tokens" and i + 1 < len(sys.argv): max_tokens = int(sys.argv[i + 1])
        elif a == "--draft-blocks" and i + 1 < len(sys.argv): draft_blocks = int(sys.argv[i + 1])
        elif a == "--temperature" and i + 1 < len(sys.argv): temperature = float(sys.argv[i + 1])
        elif a == "--retry-temperature" and i + 1 < len(sys.argv): retry_temperature = float(sys.argv[i + 1])
        elif a == "--blank-values": blank_values = True
        elif a == "--noise-draft": noise_draft = True
        elif a == "--trial" and i + 1 < len(sys.argv): trial = int(sys.argv[i + 1])

    llm = guard_llm(llm)
    if not GATE.exists():
        sys.exit(f"gate binary missing: {GATE}")

    env = build_environment("airline")
    tasks = get_tasks("airline", task_ids=[task_id])
    if not tasks:
        sys.exit(f"no task {task_id!r} in the airline domain")
    task = tasks[0]

    ins = task.user_scenario.instructions
    if isinstance(ins, list):
        ins = " ".join(str(x) for x in ins)
    print(f"Task      : {task.id} — {str(ins)[:90]}...")
    print(f"Agent     : local LLaDA2.2-mini arm={arm} steps={steps} draft={draft} frac={draft_frac}")
    print(f"User sim  : {llm}")
    print()

    import hashlib
    rlog = RunLogger(slug("airline", task_id, arm, f"s{steps}", f"t{temperature}"))
    rlog.event(
        "run_start", task=task_id, domain="airline",
        agent="airline-llada", arm=arm, steps=steps, draft=draft,
        construct=construct, draft_frac=draft_frac,
        draft_blocks=draft_blocks, blank_values=blank_values,
        noise_draft=noise_draft, max_tokens=max_tokens,
        temperature=temperature, retry_temperature=retry_temperature,
        user_sim=llm, gate=GATE.name,
        gate_sha=hashlib.sha256(GATE.read_bytes()).hexdigest()[:12],
        trial=trial, seed=42 + trial,
    )
    agent = AirlineLladaAgent(
        tools=env.get_tools(),
        domain_policy=env.get_policy(),
        gate_binary=GATE,
        arm=arm,
        draft=draft,
        construct=construct,
        draft_frac=draft_frac,
        draft_blocks=draft_blocks,
        blank_values=blank_values,
        noise_draft=noise_draft,
        steps=steps,
        max_tokens=max_tokens,
        temperature=temperature,
        retry_temperature=retry_temperature,
        rlog=rlog,
    )
    user = build_user("user_simulator", env, task, llm=llm)

    orchestrator = Orchestrator(
        domain="airline",
        agent=agent,
        user=user,
        environment=env,
        task=task,
        max_steps=20,
        max_errors=5,
        seed=42 + trial,
    )

    reward = None
    try:
        result = run_simulation(orchestrator, evaluation_type=EvaluationType.ALL)
        reward = result.reward_info.reward
    finally:
        print("\n===== agent trace =====")
        for line in agent.trace:
            print(line)
        agent.stop()
        rlog.event(
            "run_end", reward=reward,
            agent_calls=agent.call_count, gen_calls=agent.gen_calls,
            rejections=agent.rejections,
            log=str(rlog.path),
        )
        rlog.close()

    print("=" * 60)
    print(f"Reward            : {result.reward_info.reward}")
    print(f"Agent calls       : {agent.call_count} (gen calls: {agent.gen_calls}, rejections: {agent.rejections})")
    print(f"Messages          : {len(result.messages)}")
    print()
    print("Conversation:")
    for msg in result.messages:
        role = msg.role.value if hasattr(msg.role, "value") else msg.role
        tcs = getattr(msg, "tool_calls", None) or []
        if tcs:
            for tc in tcs:
                print(f"  [{role}] TOOL CALL {tc.name}({str(tc.arguments)[:120]})")
            continue
        content = str(msg.content)[:180] if msg.content else "(empty)"
        print(f"  [{role}] {content}")


if __name__ == "__main__":
    main()
