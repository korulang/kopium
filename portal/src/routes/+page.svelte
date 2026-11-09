<script>
	export let data;

	function fmtTs(ts) {
		if (!ts) return '';
		return new Date(ts * 1000).toLocaleString();
	}
	function kb(n) {
		return n > 1048576 ? (n / 1048576).toFixed(1) + ' MB' : Math.round(n / 1024) + ' KB';
	}
</script>

<svelte:head><title>kopium runs</title></svelte:head>

<main>
	<h1>kopium runs</h1>
	{#if data.missing}
		<p class="dim">No runs directory at <code>{data.runsDir}</code> — set KOPIUM_RUNS_DIR or run the bench harness first.</p>
	{:else if data.runs.length === 0}
		<p class="dim">No runs logged yet.</p>
	{:else}
		<table>
			<thead>
				<tr>
					<th>run</th><th>task</th><th>arm</th><th>steps</th><th>reward</th>
					<th>gens</th><th>rejects</th><th>size</th><th>finished</th>
				</tr>
			</thead>
			<tbody>
				{#each data.runs as r}
					<tr class:running={!r.end}>
						<td><a href="/runs/{r.id}">{r.id}</a></td>
						<td>{r.start?.task ?? '—'}</td>
						<td>{r.start?.arm ?? '—'}</td>
						<td>{r.start?.steps ?? '—'}</td>
						<td class:win={r.end?.reward > 0} class:loss={r.end && r.end.reward <= 0}>
							{r.end ? r.end.reward : '…'}
						</td>
						<td>{r.end?.gen_calls ?? '…'}</td>
						<td>{r.end?.rejections ?? '…'}</td>
						<td>{kb(r.size)}</td>
						<td class="dim">{r.end ? 'yes' : 'running'}</td>
					</tr>
				{/each}
			</tbody>
		</table>
	{/if}
</main>

<style>
	main { max-width: 1100px; margin: 2rem auto; padding: 0 1rem; font-family: ui-monospace, monospace; }
	h1 { font-size: 1.2rem; }
	table { border-collapse: collapse; width: 100%; font-size: 0.85rem; }
	th, td { text-align: left; padding: 0.35rem 0.6rem; border-bottom: 1px solid #2a2a2a; }
	th { color: #888; font-weight: normal; }
	a { color: #7ab8ff; text-decoration: none; }
	a:hover { text-decoration: underline; }
	.dim { color: #666; }
	.win { color: #6fdc8c; }
	.loss { color: #e08080; }
	.running td { opacity: 0.75; }
</style>
