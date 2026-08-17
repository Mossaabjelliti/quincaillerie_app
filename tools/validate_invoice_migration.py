"""Structural validation for the invoice numbering migration.

This is a lightweight static check (no PostgreSQL server required). It verifies
that the migration contains all required components, follows the project's
migration conventions, and contains none of the forbidden patterns.

Heuristics are intentionally conservative: comments are stripped before
checking forbidden patterns and PL/pgSQL block balance accounts for
`end if` (an IF-block terminator, not a function/DO-block terminator).
"""

import re
import sys
from pathlib import Path

MIGRATION = Path(__file__).resolve().parent.parent / "migrations" / "20260810123000_invoice_numbering.sql"


def strip_sql_comments(sql: str) -> str:
    """Remove `--` line comments. Keeps $$ ... $$ bodies and quoted literals."""
    out_lines = []
    for line in sql.splitlines():
        # Naive but adequate here: no `--` appears inside quoted strings in this file.
        idx = line.find("--")
        out_lines.append(line if idx == -1 else line[:idx])
    return "\n".join(out_lines)


def main() -> int:
    sql = MIGRATION.read_text(encoding="utf-8")
    sql_no_comments = strip_sql_comments(sql)
    errors: list[str] = []
    lines: list[str] = []

    lines.append(f"[OK] Semicolons: {sql.count(';')}")

    required = [
        ("store_sequences table", "create table if not exists public.store_sequences"),
        ("PK (store_id, year)", "primary key (store_id, year)"),
        ("next_invoice_number function", "create or replace function public.next_invoice_number"),
        ("SECURITY DEFINER", "security definer"),
        ("is_store_member gate", "public.is_store_member(p_store_id)"),
        ("ON CONFLICT atomic increment", "on conflict (store_id, year)"),
        ("RLS enable", "alter table public.store_sequences enable row level security"),
        ("invoices RLS policy", 'create policy if not exists "Store members invoices policy"'),
        ("store_id index", "invoices_store_id_idx"),
        ("sale_id unique index", "invoices_sale_id_idx"),
        ("store_number unique index", "invoices_store_number_idx"),
        ("format CHECK", "invoices_invoice_number_format_check"),
        ("revoke anon", "revoke all on table public.store_sequences from anon"),
        ("revoke authenticated", "revoke all on table public.store_sequences from authenticated"),
        ("grant execute", "grant execute on function public.next_invoice_number(text) to authenticated"),
    ]
    for name, needle in required:
        if needle in sql:
            lines.append(f"[OK] {name}")
        else:
            errors.append(name)
            lines.append(f"[FAIL] {name}")

    # Forbidden patterns are checked on the comment-stripped SQL so that docs
    # such as "NEVER MAX()+1" do not trip the scan.
    forbidden = [
        ("MAX()+1 arithmetic", r"max\s*\(\s*\)\s*\+\s*1", re.IGNORECASE),
        ("MAX(invoice_number)", r"max\s*\(\s*invoice_number", re.IGNORECASE),
        ("client invoice_number insert", r"insert\s+into\s+public\.invoices\s*\([^)]*invoice_number", re.IGNORECASE),
    ]
    for name, pattern, flags in forbidden:
        if re.search(pattern, sql_no_comments, flags):
            errors.append(name)
            lines.append(f"[FAIL] Forbidden pattern found: {name}")
        else:
            lines.append(f"[OK] No forbidden pattern: {name}")

    # The CHECK constraint stores the regex as a quoted literal, so match the
    # escaped literal text as it appears in the SQL source.
    format_literal = r"INV-[0-9]{4}-[0-9]{4,}"
    if re.search(re.escape(format_literal), sql):
        lines.append("[OK] INV-YYYY-NNNN format regex present in CHECK constraint")
    else:
        errors.append("format regex")
        lines.append("[FAIL] format regex missing")

    # PL/pgSQL block balance is validated per $$ ... $$ body (the DO block and
    # the function body). DDL `if not exists` clauses and the `if` inside
    # `end if` are not PL/pgSQL IF blocks, so scanning the whole file would
    # produce false positives.
    bodies = re.findall(r"\$\$(.*?)\$\$", sql_no_comments, re.DOTALL | re.IGNORECASE)
    if not bodies:
        errors.append("no PL/pgSQL $$ bodies found")
        lines.append("[FAIL] no PL/pgSQL $$ bodies found")
    for i, body in enumerate(bodies, start=1):
        begins = len(re.findall(r"\bbegin\b", body, re.IGNORECASE))
        # A block terminator is `end;`, `end $$`, or `end` at the very end of
        # the body (the closing `$$` delimiter is consumed by the extraction).
        end_terms = len(re.findall(r"\bend\s*(?:;|\$\$|$)", body, re.IGNORECASE))
        # `\bif\b` also matches the `if` inside `end if`, so subtract those.
        end_ifs = len(re.findall(r"\bend\s+if\b", body, re.IGNORECASE))
        ifs = len(re.findall(r"\bif\b", body, re.IGNORECASE)) - end_ifs
        lines.append(
            f"[INFO] $$ body {i}: begin={begins} block-end={end_terms} if={ifs} end-if={end_ifs}"
        )
        if begins != end_terms:
            errors.append(f"$$ body {i}: begin/block-end imbalance: {begins} vs {end_terms}")
            lines.append(f"[FAIL] $$ body {i}: begin/block-end imbalance")
        else:
            lines.append(f"[OK] $$ body {i}: begin/block-end balanced")
        if ifs != end_ifs:
            errors.append(f"$$ body {i}: if/end-if imbalance: {ifs} vs {end_ifs}")
            lines.append(f"[FAIL] $$ body {i}: if/end-if imbalance")
        else:
            lines.append(f"[OK] $$ body {i}: if/end-if balanced")

    if re.match(r"^\d{14}_[a-z0-9_]+\.sql$", MIGRATION.name):
        lines.append("[OK] Migration filename convention")
    else:
        errors.append("filename convention")
        lines.append("[FAIL] Migration filename convention")

    lines.append("")
    if errors:
        lines.append(f"RESULT: FAIL - {len(errors)} issue(s): {errors}")
    else:
        lines.append("RESULT: PASS - all structural checks passed")

    print("\n".join(lines))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())