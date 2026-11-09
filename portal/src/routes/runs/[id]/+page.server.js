import { readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { error } from '@sveltejs/kit';
import { RUNS_DIR } from '$lib/runs';

export function load({ params }) {
	if (!/^[\w.-]+$/.test(params.id)) throw error(404, 'bad run id');
	const file = path.join(RUNS_DIR, params.id + '.jsonl');
	if (!existsSync(file)) throw error(404, 'run not found');
	const events = [];
	for (const line of readFileSync(file, 'utf8').split('\n')) {
		if (!line.trim()) continue;
		try {
			events.push(JSON.parse(line));
		} catch {
			// partial last line of an in-flight run — skip
		}
	}
	return { runId: params.id, events };
}
