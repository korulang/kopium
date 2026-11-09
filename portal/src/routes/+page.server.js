import { readdirSync, openSync, readSync, closeSync, fstatSync, statSync } from 'node:fs';
import path from 'node:path';
import { RUNS_DIR } from '$lib/runs';

function firstLine(file) {
	const fd = openSync(file, 'r');
	try {
		const buf = Buffer.alloc(262144);
		const n = readSync(fd, buf, 0, buf.length, 0);
		const text = buf.subarray(0, n).toString('utf8');
		const nl = text.indexOf('\n');
		return nl === -1 ? text : text.slice(0, nl);
	} finally {
		closeSync(fd);
	}
}

function lastLine(file) {
	const size = statSync(file).size;
	if (size === 0) return '';
	const fd = openSync(file, 'r');
	try {
		const len = Math.min(size, 65536);
		const buf = Buffer.alloc(len);
		readSync(fd, buf, 0, len, size - len);
		const text = buf.toString('utf8');
		const lines = text.split('\n').filter((l) => l.trim());
		return lines.length ? lines[lines.length - 1] : '';
	} finally {
		closeSync(fd);
	}
}

function parseMaybe(s) {
	try {
		return JSON.parse(s);
	} catch {
		return null;
	}
}

export function load() {
	let files = [];
	try {
		files = readdirSync(RUNS_DIR).filter((f) => f.endsWith('.jsonl'));
	} catch {
		return { runs: [], runsDir: RUNS_DIR, missing: true };
	}
	const runs = files
		.map((name) => {
			const file = path.join(RUNS_DIR, name);
			const start = parseMaybe(firstLine(file));
			const end = parseMaybe(lastLine(file));
			const st = statSync(file);
			return {
				id: name.replace(/\.jsonl$/, ''),
				start,
				end: end && end.type === 'run_end' ? end : null,
				size: st.size,
				mtime: st.mtimeMs
			};
		})
		.sort((a, b) => b.mtime - a.mtime);
	return { runs, runsDir: RUNS_DIR, missing: false };
}
