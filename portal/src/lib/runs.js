import path from 'node:path';

// Run logs are emitted by bench/runlog.py into <repo>/logs/runs.
// Override with KOPIUM_RUNS_DIR when the portal runs elsewhere.
export const RUNS_DIR = process.env.KOPIUM_RUNS_DIR
	? path.resolve(process.env.KOPIUM_RUNS_DIR)
	: path.resolve(process.cwd(), '..', 'logs', 'runs');
