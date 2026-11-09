<script>
	export let data;

	const events = data.events;
	const start = events.find((e) => e.type === 'run_start');
	const end = events.find((e) => e.type === 'run_end');
	const system = events.find((e) => e.type === 'system');
	const timeline = events.filter((e) => !['run_start', 'run_end', 'system'].includes(e.type));

	function cls(status) {
		if (status === 'OK') return 'ok';
		if (status === 'HALT' || status === 'REJECT' || status === 'ERROR') return 'bad';
		return 'mid';
	}
	function short(s, n = 140) {
		if (s == null) return '';
		s = String(s);
		return s.length > n ? s.slice(0, n) + '…' : s;
	}
	function chars(msgs) {
		return msgs.reduce((a, m) => a + (m.content ? m.content.length : 0), 0);
	}
	function cfg(k) {
		return start ? start[k] : undefined;
	}
</script>

<svelte:head><title>run {data.runId}</title></svelte:head>

<main>
	<p class="crumb"><a href="/">← runs</a></p>
	<h1>{data.runId}</h1>

	{#if start}
		<div class="cfg">
			<span>task <b>{cfg('task')}</b></span>
			<span>domain <b>{cfg('domain')}</b></span>
			<span>agent <b>{cfg('agent')}</b></span>
			<span>arm <b>{cfg('arm')}</b></span>
			<span>steps <b>{cfg('steps')}</b></span>
			<span>draft <b>{cfg('draft') ?? '—'}</b></span>
			<span>user sim <b>{cfg('user_sim')}</b></span>
			{#if end}
				<span class="reward {end.reward > 0 ? 'win' : 'loss'}">reward <b>{end.reward}</b></span>
				<span>calls <b>{end.agent_calls}</b></span>
				<span>gens <b>{end.gen_calls}</b></span>
				<span>rejects <b>{end.rejections}</b></span>
			{:else}
				<span class="dim">still running…</span>
			{/if}
		</div>
	{/if}

	{#if system}
		<details class="sys">
			<summary>system prompt ({system.text.length} chars)</summary>
			<pre>{system.text}</pre>
		</details>
	{/if}

	<div class="timeline">
		{#each timeline as e, i (i)}
			{#if e.type === 'gen'}
				<section class="card gen">
					<summary class="gen-head">
						<span class="tag gen-tag">GEN #{e.n}</span>
						<span class="dim">temp {e.temperature}</span>
						<span class="dim">{e.response.wall_s}s</span>
						<span class="dim">{e.response.gen_tokens} tok</span>
						<span class="dim">prompt {e.response.prompt_tokens}</span>
						{#if e.response.draft_positions != null}
							<span class="dim">draft {e.response.draft_positions}/{e.response.draft_revisions}</span>
						{/if}
						<span class="dim">ctx {e.messages.length} msgs / {chars(e.messages)} chars</span>
					</summary>

					<details class="ctx">
						<summary>context sent to model</summary>
						{#each e.messages as m}
							<div class="msg {m.role}">
								<div class="msg-role">{m.role}</div>
								<pre>{m.content}</pre>
							</div>
						{/each}
					</details>

					<div class="response">
						<div class="msg-role">model</div>
						<pre>{e.response.text}</pre>
					</div>
				</section>

			{:else if e.type === 'wire' || e.type === 'flow'}
				<div class="ev wire">
					<span class="tag">{e.type === 'wire' ? 'WIRE' : 'FLOW'}</span>
					<pre>{e.text}</pre>
				</div>

			{:else if e.type === 'gate_call'}
				<div class="ev call">
					<span class="tag">CALL</span>
					<b>{e.name}</b>
					<code>{JSON.stringify(e.arguments)}</code>
				</div>

			{:else if e.type === 'gate_say'}
				<div class="ev say">
					<span class="tag say-tag">SAY → user</span>
					<span>{e.text}</span>
				</div>

			{:else if e.type === 'gate_status'}
				<div class="ev status">
					<span class="badge {cls(e.status)}">{e.status}</span>
					<details class="detail">
						<summary class="dim">{short(e.detail, 160)}</summary>
						<pre>{e.detail}</pre>
					</details>
				</div>

			{:else if e.type === 'observe'}
				<div class="ev observe">
					<span class="tag obs-tag">→ ctx</span>
					<span class="dim">[{e.role}]</span> {short(e.content, 200)}
				</div>

			{:else if e.type === 'reject'}
				<div class="ev reject">
					<span class="badge bad">REJECT</span>
					<span>{short(e.reason, 200)}</span>
					{#if e.attempt != null}<span class="dim">attempt {e.attempt}</span>{/if}
				</div>
			{/if}
		{/each}
	</div>
</main>

<style>
	main { max-width: 1000px; margin: 0 auto; padding: 1rem; font-family: ui-monospace, monospace; font-size: 0.85rem; }
	.crumb a { color: #7ab8ff; text-decoration: none; }
	h1 { font-size: 1.1rem; margin: 0.25rem 0 0.75rem; word-break: break-all; }
	.cfg { display: flex; flex-wrap: wrap; gap: 0.5rem 1.25rem; padding: 0.6rem 0.8rem; background: #161616; border: 1px solid #2a2a2a; border-radius: 6px; margin-bottom: 1rem; }
	.cfg span { color: #888; }
	.cfg b { color: #ddd; font-weight: normal; }
	.reward.win b { color: #6fdc8c; }
	.reward.loss b { color: #e08080; }
	.dim { color: #666; }
	a { color: #7ab8ff; }

	.sys { margin-bottom: 1rem; }
	details summary { cursor: pointer; color: #888; }
	details pre, .ev pre, .response pre, .msg pre {
		background: #101010; border: 1px solid #262626; border-radius: 4px;
		padding: 0.5rem 0.7rem; overflow-x: auto; white-space: pre-wrap;
		word-break: break-word; font-size: 0.8rem; margin: 0.3rem 0;
	}

	.timeline { display: flex; flex-direction: column; gap: 0.6rem; }
	.card.gen { background: #141414; border: 1px solid #2a2a2a; border-radius: 6px; padding: 0.5rem 0.8rem; }
	.gen-head { display: flex; flex-wrap: wrap; gap: 0.4rem 1rem; align-items: baseline; cursor: default; list-style: none; }
	.gen-head::-webkit-details-marker { display: none; }
	.tag { font-size: 0.7rem; letter-spacing: 0.08em; color: #7ab8ff; border: 1px solid #2a3a4a; border-radius: 3px; padding: 0.1rem 0.4rem; }
	.gen-tag { color: #c9a7ff; border-color: #3a2a4a; }
	.say-tag { color: #6fdc8c; border-color: #1f3a2a; }
	.obs-tag { color: #666; border-color: #2a2a2a; }

	.ctx { margin-top: 0.5rem; }
	.msg { margin: 0.4rem 0; }
	.msg-role { font-size: 0.7rem; color: #888; text-transform: uppercase; letter-spacing: 0.06em; margin-bottom: 0.15rem; }
	.msg.user .msg-role { color: #6fdc8c; }
	.msg.assistant .msg-role { color: #7ab8ff; }
	.msg.system .msg-role { color: #c9a7ff; }

	.response { border-top: 1px dashed #2a2a2a; margin-top: 0.6rem; padding-top: 0.4rem; }

	.ev { display: flex; flex-wrap: wrap; gap: 0.5rem 0.8rem; align-items: baseline; padding: 0.3rem 0.6rem; border-left: 3px solid #333; }
	.ev.wire, .ev.flow { border-left-color: #7ab8ff; }
	.ev.wire pre { margin: 0.3rem 0 0; width: 100%; }
	.ev.call { border-left-color: #c9a7ff; }
	.ev.call code { color: #bbb; word-break: break-all; }
	.ev.say { border-left-color: #6fdc8c; }
	.ev.observe { border-left-color: #333; font-size: 0.8rem; }
	.ev.reject { border-left-color: #e08080; }
	.ev.status { border-left-color: #555; }

	.badge { font-size: 0.7rem; font-weight: bold; padding: 0.1rem 0.45rem; border-radius: 3px; }
	.badge.ok { background: #14301c; color: #6fdc8c; }
	.badge.bad { background: #3a1515; color: #e08080; }
	.badge.mid { background: #2a2410; color: #d8c060; }
	.detail summary { display: inline; }
	.detail pre { width: 100%; }
</style>
