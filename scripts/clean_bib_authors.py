#!/usr/bin/env python3
"""
Clean author name inconsistencies in references.bib.

For each surname, groups all given-name variants and standardizes
to the most complete version when variants clearly refer to the
same person (initials match the full name).

Conservative: leaves genuinely different people alone.
"""

import re
import shutil
import sys
from collections import defaultdict
from pathlib import Path


BIB_PATH = Path("/ipl/ipl27/sfernandez/thesis_phd/references.bib")
BAK_PATH = BIB_PATH.with_suffix(".bib.bak")


# ── Helpers ──────────────────────────────────────────────────────

def normalize_ws(s):
    """Collapse whitespace."""
    return re.sub(r"\s+", " ", s).strip()


def parse_given_tokens(given):
    """
    Split a given-name string into tokens.

    Each token is either a full name, a single initial (with or
    without period), or a compound initial like "LR" / "E.J."

    We expand compound initials into separate single-letter tokens.
    E.g.:
      "C.R."        -> ["C.", "R."]
      "Clifford R." -> ["Clifford", "R."]
      "Timothy EJ"  -> ["Timothy", "E.", "J."]
      "Jesper LR"   -> ["Jesper", "L.", "R."]
      "W. J. P."    -> ["W.", "J.", "P."]
      "Wouter JP"   -> ["Wouter", "J.", "P."]
      "Theo G.M."   -> ["Theo", "G.", "M."]
      "J-Sebastian"  -> ["J-Sebastian"]  (hyphenated, keep as is)
    """
    given = normalize_ws(given)

    # Split glued initials with periods: "C.R." -> "C. R."
    # Repeat to catch chains like "G.E."
    given = re.sub(r"([A-Za-z])\.([A-Za-z])", r"\1. \2", given)
    given = re.sub(r"([A-Za-z])\.([A-Za-z])", r"\1. \2", given)

    raw_tokens = given.split()
    tokens = []

    for tok in raw_tokens:
        stripped = tok.rstrip(".")
        # Hyphenated names like "J-Sebastian" -- keep as-is
        if "-" in tok:
            tokens.append(tok)
        # Compound uppercase initials without periods: "LR", "EJ",
        # "JP", "GM", "EM" -- expand into individual initials.
        # Must be 2-3 uppercase letters, no lowercase.
        elif (
            len(stripped) >= 2
            and stripped.isalpha()
            and stripped.isupper()
        ):
            for ch in stripped:
                tokens.append(ch + ".")
        else:
            tokens.append(tok)

    return tokens


def token_is_initial(tok):
    """
    Check if a token is a single-letter initial
    (maybe with period).
    """
    stripped = tok.strip(".")
    return len(stripped) == 1 and stripped.isalpha()


def token_completeness(tok):
    """
    Score: full name (2) > initial with period (1) > bare
    initial (0).
    """
    if token_is_initial(tok):
        return 1 if tok.endswith(".") else 0
    return 2


def tokens_compatible(tok_a, tok_b):
    """
    Check if two name tokens could refer to the same person.

    "Clifford" and "C." -> True
    "C." and "C"        -> True
    "Clifford" and "Christopher" -> False
    """
    # Strip periods for comparison
    a = tok_a.strip(".")
    b = tok_b.strip(".")

    # Must share the same first letter
    if a[0].upper() != b[0].upper():
        return False

    # Both initials: same letter = match
    if token_is_initial(tok_a) and token_is_initial(tok_b):
        return True

    # One initial, one full: compatible
    if token_is_initial(tok_a) or token_is_initial(tok_b):
        return True

    # Both full names: must match (case-insensitive)
    return a.lower() == b.lower()


def givens_compatible(tokens_a, tokens_b):
    """
    Check if two given-name token lists could be the same person.
    Compares overlapping positions only.
    """
    min_len = min(len(tokens_a), len(tokens_b))
    if min_len == 0:
        return False
    for i in range(min_len):
        if not tokens_compatible(tokens_a[i], tokens_b[i]):
            return False
    return True


def select_best_token(tok_a, tok_b):
    """Pick the more complete of two compatible tokens."""
    sa = token_completeness(tok_a)
    sb = token_completeness(tok_b)
    if sa >= sb:
        return tok_a
    return tok_b


def merge_token_lists(lists):
    """
    Given a list of compatible token lists, produce the canonical
    form. Uses the longest list as the base, picks the best token
    at each position.
    """
    if not lists:
        return []
    lists_sorted = sorted(
        lists,
        key=lambda toks: (
            len(toks),
            sum(token_completeness(t) for t in toks),
        ),
        reverse=True,
    )
    best = list(lists_sorted[0])
    for other in lists_sorted[1:]:
        for i in range(min(len(best), len(other))):
            best[i] = select_best_token(best[i], other[i])
    return best


def format_given(tokens):
    """
    Format tokens back to a string.
    Ensures periods after single-letter initials, spaces between
    all tokens.
    """
    result = []
    for tok in tokens:
        if token_is_initial(tok):
            result.append(tok[0].upper() + ".")
        else:
            result.append(tok)
    return " ".join(result)


# ── BibTeX parsing ───────────────────────────────────────────────

def extract_author_field(line):
    """
    Extract author field content.
    Returns (prefix, authors_str, suffix) or None.
    """
    m = re.match(
        r"^(\s*author\s*=\s*\{)(.*?)(\},?\s*)$",
        line, re.IGNORECASE,
    )
    if m:
        return m.group(1), m.group(2), m.group(3)
    return None


def split_authors(authors_str):
    """
    Split author string by ' and ' respecting curly braces.
    """
    authors = []
    depth = 0
    current = []
    i = 0
    while i < len(authors_str):
        ch = authors_str[i]
        if ch == "{":
            depth += 1
            current.append(ch)
            i += 1
        elif ch == "}":
            depth -= 1
            current.append(ch)
            i += 1
        elif depth == 0 and authors_str[i:i + 5] == " and ":
            authors.append("".join(current))
            current = []
            i += 5
        else:
            current.append(ch)
            i += 1
    if current:
        authors.append("".join(current))
    return authors


def parse_author_name(author_str):
    """
    Parse "Surname, Given" into (surname, given).
    Returns None for corporate/unparseable authors.
    """
    author_str = author_str.strip()

    if author_str.lower() == "others":
        return None
    if author_str.startswith("{") and author_str.endswith("}"):
        return None
    if "Initiative" in author_str and "Alzheimer" in author_str:
        return None
    if "PREVENT-AD" in author_str or "ADNI" in author_str:
        return None
    if author_str.startswith(","):
        return None
    if "Consortium" in author_str:
        return None
    # "WU-Minn HCP Consortium" etc handled above via braces

    if "," in author_str:
        parts = author_str.split(",", 1)
        surname = parts[0].strip()
        given = parts[1].strip() if len(parts) > 1 else ""
        if surname and given:
            return (surname, given)
    return None


# ── Hardcoded skip list for tricky cases ─────────────────────────
# These are surnames where variants look compatible by algorithm
# but are actually different people, or where the automated merge
# would produce wrong results.

SKIP_SURNAMES = set()

# Cases where compound initials or unusual name patterns cause
# the algorithm to produce wrong canonical forms.  We handle
# these via an explicit override map instead.

MANUAL_OVERRIDES = {
    # Andersson: "Jesper LR" and "Jesper L. R." are the same
    # LR -> L. R. after expansion, so the algorithm handles it.
    # But verify canonical is "Jesper L. R."

    # Behrens: "Timothy EJ" -> "Timothy E. J." after expansion
    # That should merge with "Timothy E. J." Fine.

    # Henneman: "Wouter JP" -> "Wouter J. P." after expansion
    # Should merge with "W. J. P." Fine.

    # Van Erp: "Theo GM" -> "Theo G. M."
    # "Theo G.M." -> "Theo G. M." (already expanded)
    # "T G M" -> "T. G. M."  "T. G. M." as well
    # These should all merge. Fine.

    # Van Haren: "Neeltje EM" -> "Neeltje E. M."
    # "N E M" -> "N. E. M." These should merge. Fine.

    # Nelson: "E. Anne" vs "Edward A" -- these ARE the same person
    # (E. Anne Nelson, same paper). "E." matches "Edward"? No --
    # "E." is an initial. "Anne" is a full name.
    # "Edward" and "Anne" -- both full, first letters E vs A -> not
    # compatible! So the algorithm should NOT merge them.
    # But the first tokens ARE compatible: "E." matches "Edward".
    # Second tokens: "Anne" vs "A" -- "A" is initial, "Anne" starts
    # with A, so compatible. This is WRONG -- it's "E. Anne" as in
    # the name is literally "E. Anne Nelson".
    # We need to skip this case.
    ("nelson", "E. Anne"): "E. Anne",
    ("nelson", "Edward A"): "Edward A.",

    # Muehlboeck: "J Sebastian" vs "J-Sebastian"
    # "J" is initial, "Sebastian" is full name
    # "J-Sebastian" is a hyphenated first name
    # These should become "J-Sebastian" but the token structures
    # differ. Skip and handle manually.
    ("muehlboeck", "J Sebastian"): "J-Sebastian",
    ("muehlboeck", "J-Sebastian"): "J-Sebastian",

    # Ntiri: "Emmanuel E" vs "Emmanuel Edward"
    # These ARE the same person. "E" matches "Edward". Good.
    # Canonical should be "Emmanuel Edward". Algorithm handles it.

    # Foo: "Heidi J L" -> expands to "Heidi J. L."
    # vs "Heidi Jing Ling" -- J. matches Jing, L. matches Ling.
    # Algorithm should handle it -- canonical "Heidi Jing Ling".

    # Lim: "Joseph K W" -> "Joseph K. W."
    # vs "Joseph Kai Wei" -- same logic. Fine.

    # Iglesias: "J. Eugenio" vs "Juan Eugenio"
    # J. matches Juan. Fine -> "Juan Eugenio".

    # Manjón: "José V" / "José V." vs "José Vicente"
    # V. matches Vicente. Fine -> "José Vicente".

    # Biessels: only appears as "Geert Jan" and "Geert J."
    # J. matches Jan. Fine -> "Geert Jan".

    # Fonov: "Vladimir" vs "Vladimir S."
    # Subset: "Vladimir" is prefix. Compatible -> "Vladimir S."

    # Ikram: "M Arfan" vs "M. A." vs "M. Arfan"
    # "M" and "M." compatible, "Arfan" and "A." compatible.
    # -> "M. Arfan". Fine.

    # Raket: "Lars L." vs "Lars Lau"
    # L. matches Lau -> "Lars Lau". Fine.

    # Sudo: "Felipe K" vs "Felipe Kenji"
    # K matches Kenji -> "Felipe Kenji". Fine.

    # Pinho: "Márcio S" vs "Márcio Sarroglia"
    # S matches Sarroglia -> "Márcio Sarroglia". Fine.

    # Ramasamy: "Deepa P" vs "Deepa Preeti"
    # P matches Preeti -> "Deepa Preeti". Fine.
}


# ── Build maps ───────────────────────────────────────────────────

def build_author_map(bib_lines):
    """
    Collect all (surname, given) variants.
    Returns dict: norm_surname -> set of given-name strings.
    """
    surname_givens = defaultdict(set)
    for line in bib_lines:
        parsed = extract_author_field(line)
        if not parsed:
            continue
        _, authors_str, _ = parsed
        for author_str in split_authors(authors_str):
            name = parse_author_name(author_str)
            if name is None:
                continue
            surname, given = name
            norm_surname = (
                surname.lower().strip().replace(".", "")
            )
            surname_givens[norm_surname].add(given)
    return surname_givens


def is_all_initials(tokens):
    """True if every token in the list is a single-letter initial."""
    return all(token_is_initial(t) for t in tokens)


def ambiguous_initial_match(
    norm_surname, g_init, tokens_init, given_tokens
):
    """
    Check if an initials-only variant has MULTIPLE DISTINCT
    full-name matches for the same surname.  If so, the merge
    is ambiguous and should be skipped.

    E.g. for surname "Chen":
      "C." could match both "Congxin" and "Christopher"
      -> ambiguous, skip.
    But if "C." matches "Clifford R.", "Clifford R", and
    "Clifford" -- those are all the SAME person, so it's safe.
    """
    # Collect all non-initial variants that are compatible
    # with this initials-only variant
    compatible = []
    for g2, toks2 in given_tokens.items():
        if g2 == g_init:
            continue
        if is_all_initials(toks2):
            continue
        if givens_compatible(tokens_init, toks2):
            compatible.append((g2, toks2))

    if len(compatible) <= 1:
        return False

    # Check if all compatible matches refer to the same
    # person (i.e., they are all mutually compatible).
    # If any pair is NOT compatible, they're different
    # people -> ambiguous.
    for i in range(len(compatible)):
        for j in range(i + 1, len(compatible)):
            if not givens_compatible(
                compatible[i][1], compatible[j][1]
            ):
                return True  # ambiguous

    return False  # all compatible = same person


def build_replacement_map(surname_givens):
    """
    For each surname, group compatible given-name variants
    and determine canonical form.

    Returns dict:
      (norm_surname, normalized_given) -> canonical_given
    """
    replacements = {}

    for norm_surname, givens in surname_givens.items():
        if norm_surname in SKIP_SURNAMES:
            continue
        if len(givens) <= 1:
            continue

        # Parse each given into tokens
        given_tokens = {}
        for g in givens:
            # Check manual override first
            if (norm_surname, g) in MANUAL_OVERRIDES:
                continue
            tokens = parse_given_tokens(g)
            if tokens:
                given_tokens[g] = tokens

        if len(given_tokens) <= 1:
            continue

        # Skip ambiguous initials-only variants: if a
        # pure-initials variant has multiple possible
        # full-name matches, don't merge any of them.
        skip_givens = set()
        for g, toks in given_tokens.items():
            if is_all_initials(toks):
                if ambiguous_initial_match(
                    norm_surname, g, toks, given_tokens
                ):
                    skip_givens.add(g)

        # Group compatible variants
        groups = []
        used = set()
        givens_list = [
            g for g in given_tokens if g not in skip_givens
        ]

        for i, g1 in enumerate(givens_list):
            if g1 in used:
                continue
            group = [g1]
            used.add(g1)
            for j in range(i + 1, len(givens_list)):
                g2 = givens_list[j]
                if g2 in used:
                    continue
                if all(
                    givens_compatible(
                        given_tokens[gm], given_tokens[g2]
                    )
                    for gm in group
                ):
                    group.append(g2)
                    used.add(g2)
            groups.append(group)

        # Determine canonical form for each group
        for group in groups:
            if len(group) <= 1:
                continue
            token_lists = [given_tokens[g] for g in group]
            canonical_tokens = merge_token_lists(token_lists)
            canonical = format_given(canonical_tokens)

            for g in group:
                if g != canonical:
                    norm_given = normalize_ws(g)
                    replacements[
                        (norm_surname, norm_given)
                    ] = canonical

    # Add manual overrides
    for (ns, orig), canon in MANUAL_OVERRIDES.items():
        norm_given = normalize_ws(orig)
        if orig != canon:
            replacements[(ns, norm_given)] = canon

    return replacements


def collect_surname_forms(bib_lines):
    """
    Collect surface forms of each surname.
    Returns dict: norm_surname -> most common surface form.
    """
    surname_counts = defaultdict(lambda: defaultdict(int))
    for line in bib_lines:
        parsed = extract_author_field(line)
        if not parsed:
            continue
        _, authors_str, _ = parsed
        for author_str in split_authors(authors_str):
            name = parse_author_name(author_str)
            if name is None:
                continue
            surname, _ = name
            norm = (
                surname.lower().strip().replace(".", "")
            )
            surname_counts[norm][surname] += 1

    best = {}
    for norm, forms in surname_counts.items():
        best[norm] = max(
            forms.keys(),
            key=lambda f: (forms[f], len(f)),
        )
    return best


# ── Apply replacements ───────────────────────────────────────────

def apply_replacements(bib_lines, replacements, surname_forms):
    """
    Rewrite author fields using the replacement map.
    Returns (new_lines, change_count).
    """
    new_lines = []
    total_changes = 0

    for line in bib_lines:
        parsed = extract_author_field(line)
        if not parsed:
            new_lines.append(line)
            continue

        prefix, authors_str, suffix = parsed
        author_strs = split_authors(authors_str)
        changed = False
        new_authors = []

        for author_str in author_strs:
            name = parse_author_name(author_str)
            if name is None:
                new_authors.append(author_str)
                continue

            surname, given = name
            norm_surname = (
                surname.lower().strip().replace(".", "")
            )
            norm_given = normalize_ws(given)

            # Check replacement map
            key = (norm_surname, norm_given)
            if key in replacements:
                new_given = replacements[key]
                best_surname = surname_forms.get(
                    norm_surname, surname
                )
                new_author = f"{best_surname}, {new_given}"
                if new_author != author_str.strip():
                    new_authors.append(new_author)
                    changed = True
                    continue

            # Fix surname form even if given is unchanged
            best_surname = surname_forms.get(
                norm_surname, surname
            )
            if best_surname != surname:
                new_author = f"{best_surname}, {given}"
                if new_author != author_str.strip():
                    new_authors.append(new_author)
                    changed = True
                    continue

            new_authors.append(author_str)

        if changed:
            new_line = (
                prefix + " and ".join(new_authors) + suffix
            )
            new_lines.append(new_line)
            total_changes += 1
        else:
            new_lines.append(line)

    return new_lines, total_changes


# ── ADNI Initiative fix ──────────────────────────────────────────

def fix_adni_initiative(bib_lines):
    """
    Standardize all ADNI Initiative author variants to:
      {Alzheimer's Disease Neuroimaging Initiative}
    """
    changes = 0
    new_lines = []

    for line in bib_lines:
        parsed = extract_author_field(line)
        if not parsed:
            new_lines.append(line)
            continue

        prefix, authors_str, suffix = parsed
        original = authors_str

        # Pattern fragment matching apostrophe variants
        # (ASCII ', curly ', or missing)
        APO = r"[\'\u2019]?s?"

        # "Initiative, Alzheimer's Disease Neuroimaging"
        authors_str = re.sub(
            r"Initiative,\s*Alzheimer" + APO
            + r"\s+Disease\s+Neuroimaging",
            r"{Alzheimer's Disease Neuroimaging Initiative}",
            authors_str,
        )
        # "Initiative, For the ..."
        authors_str = re.sub(
            r"Initiative,\s*For\s+the\s+Alzheimer" + APO
            + r"\s+Disease\s+Neuroimaging",
            r"{Alzheimer's Disease Neuroimaging Initiative}",
            authors_str,
        )
        # "Initiative, for the Alzheimers ..."
        authors_str = re.sub(
            r"Initiative,\s*for\s+the\s+Alzheimer" + APO
            + r"\s+Disease\s+Neuroimaging",
            r"{Alzheimer's Disease Neuroimaging Initiative}",
            authors_str,
        )
        # "Initiative (ADNI), ..."
        authors_str = re.sub(
            r"Initiative\s*\(ADNI\),\s*Alzheimer" + APO
            + r"\s+Disease\s+Neuroimaging",
            r"{Alzheimer's Disease Neuroimaging Initiative}",
            authors_str,
        )
        # ", the Alzheimer's ..." (leading comma)
        authors_str = re.sub(
            r",\s*the\s+Alzheimer" + APO
            + r"\s+Disease\s+Neuroimaging\s+Initiative",
            r"{Alzheimer's Disease Neuroimaging Initiative}",
            authors_str,
        )
        # "{For Alzheimer's Disease Neuroimaging Initiative}"
        authors_str = re.sub(
            r"\{For\s+Alzheimer" + APO
            + r"\s+Disease\s+Neuroimaging\s+Initiative\}",
            r"{Alzheimer's Disease Neuroimaging Initiative}",
            authors_str,
        )

        if authors_str != original:
            new_lines.append(prefix + authors_str + suffix)
            changes += 1
        else:
            new_lines.append(line)

    return new_lines, changes


# ── Reporting ────────────────────────────────────────────────────

def report_groups(surname_givens, replacements):
    """Print standardization report."""
    print("\n=== Author Name Standardization Report ===\n")

    by_surname = defaultdict(list)
    for (ns, ng), canon in replacements.items():
        by_surname[ns].append((ng, canon))

    for ns in sorted(by_surname.keys()):
        items = by_surname[ns]
        print(f"  {ns.title()}:")
        for orig, canon in sorted(items, key=lambda x: x[0]):
            print(f"    '{orig}' -> '{canon}'")
        print()

    total = sum(len(v) for v in by_surname.values())
    print(f"Total variant -> canonical mappings: {total}")
    print(f"Surnames affected: {len(by_surname)}")


# ── Main ─────────────────────────────────────────────────────────

def main():
    text = BIB_PATH.read_text(encoding="utf-8")
    lines = text.splitlines(keepends=True)

    # Backup
    shutil.copy2(BIB_PATH, BAK_PATH)
    print(f"Backup created: {BAK_PATH}")

    # Step 1: Fix ADNI Initiative variants
    lines, adni_changes = fix_adni_initiative(lines)
    print(f"\nADNI Initiative entries fixed: {adni_changes}")

    # Step 2: Build author map
    surname_givens = build_author_map(lines)
    surname_forms = collect_surname_forms(lines)

    # Step 3: Build replacement map
    replacements = build_replacement_map(surname_givens)

    # Step 4: Report
    report_groups(surname_givens, replacements)

    # Step 5: Apply replacements
    new_lines, author_changes = apply_replacements(
        lines, replacements, surname_forms
    )

    print(f"\nAuthor field lines modified: {author_changes}")
    print(
        f"Total lines modified (including ADNI): "
        f"{author_changes + adni_changes}"
    )

    # Write output
    BIB_PATH.write_text("".join(new_lines), encoding="utf-8")
    print(f"\nWrote cleaned file: {BIB_PATH}")

    # Verify no data loss
    orig_count = len(re.findall(r"^@", text, re.MULTILINE))
    new_text = "".join(new_lines)
    new_count = len(re.findall(r"^@", new_text, re.MULTILINE))
    print(
        f"\nVerification: {orig_count} entries before, "
        f"{new_count} entries after"
    )
    if orig_count != new_count:
        print("WARNING: Entry count changed!")
        sys.exit(1)


if __name__ == "__main__":
    main()
