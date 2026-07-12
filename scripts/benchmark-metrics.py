#!/usr/bin/env python3
"""Read Dart benchmark output and produce a per-category metrics table.

Usage:
  python3 scripts/benchmark-metrics.py <benchmark_output.json>

Output format is JSON with per-category precision, recall, F1, MRR, and
irrelevant intrusion counts. Never contains transcript text.

Run from the bench_config schema to get category descriptions.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]


def load_benchmark_output(path: str) -> dict:
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def load_category_descriptions() -> dict:
    config_path = REPO_ROOT / "evaluation" / "memory" / "benchmark" / "benchmark_config.json"
    if not config_path.exists():
        return {}
    with open(config_path, encoding="utf-8") as fh:
        config = json.load(fh)
    return config.get("categories", {})


def format_metrics(data: dict) -> dict:
    by_category = data.get("by_category", {})
    overall = data.get("overall", {})
    descriptions = load_category_descriptions()

    categories_out = {}
    for cat, metrics in sorted(by_category.items()):
        desc = descriptions.get(cat, {}).get("description", "")
        categories_out[cat] = {
            "description": desc,
            "query_count": metrics["query_count"],
            "precision": round(metrics["avg_precision"], 3),
            "recall": round(metrics["avg_recall"], 3),
            "f1": round(metrics["avg_f1"], 3),
            "mrr": round(metrics["avg_mrr"], 3),
            "irrelevant_intrusions": metrics["total_irrelevant_intrusions"],
            "queries_passed": f"{metrics['pass_count']}/{metrics['query_count']}",
        }

    return {
        "total_queries": overall.get("total_queries", 0),
        "seed_memory_count": data.get("seed_memory_count", 0),
        "overall": {
            "precision": round(overall.get("avg_precision", 0), 3),
            "recall": round(overall.get("avg_recall", 0), 3),
            "f1": round(overall.get("avg_f1", 0), 3),
            "mrr": round(overall.get("avg_mrr", 0), 3),
            "irrelevant_intrusions": overall.get("total_irrelevant_intrusions", 0),
            "queries_passed": f"{overall.get('pass_count', 0)}/{overall.get('total_queries', 0)}",
        },
        "by_category": categories_out,
    }


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: benchmark-metrics.py <benchmark_output.json>")
        sys.exit(1)

    data = load_benchmark_output(sys.argv[1])
    metrics = format_metrics(data)
    print(json.dumps(metrics, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
