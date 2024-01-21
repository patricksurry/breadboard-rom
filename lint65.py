import re
import sys

# See macro-expansion PR https://github.com/cc65/cc65/pull/2279

nolint_pattern = re.compile(r'(;|/\*)\s*NOLINT')
ident = r'\.?[_A-Za-z][_A-Za-z0-9$@]+'
ident_def_pattern = re.compile(rf'({ident})\s*(\:?=)')
label_def_pattern = re.compile(rf'({ident}):(?!=)')


def strip_comments(lst_lines):
    """Parse lines from a lst file and return (lno, asm, src) tuples excluding comments"""
    out_lines = []
    state = None        # None, ", ;, *
    comment_states = (';', '*')
    comment = ''
    for i, line in enumerate(lst_lines):
        if not (len(line) > 24 and re.match(r'[0-9a-fA-F]+r?', line)):
            # excluding header, all list lines have 24 bytes of asm output followed by source
            # 00045Fr 2  8D 00 60     right:  sta VIA_IORB
            continue
        asm, line = line[:24], line[24:]
        src = ''
        prev = None
        for c in line:
            if state in comment_states:
                comment += c
                if c == '/' and prev == '*':
                    if nolint_pattern.match(comment):
                        src = ''
                        break
                    comment = ''
                    state = None
            else:
                if state == '"':
                    if c == '"' and prev != '\\':
                        state = None
                elif c == '"' or c == ';' or (c == '*' and prev == '/'):
                    state = c
                    if c == '*':
                        src, comment = src[:-1], src[-1:]
                if state in comment_states:
                    comment += c
                else:
                    src += c
            prev = c
        if nolint_pattern.match(comment):
            src = ''
        if state == ';':
            comment = ''
            state = None
        elif state == '"':
            abbrev = line if len(line) < 40 else (line[:40] + '...')
            raise SyntaxError(f"Unterminated string at line {i+1}: {abbrev}")
        src = src.rstrip()
        if src:
            out_lines.append((i+1, asm, src))
    return out_lines


def slurp_identifiers(lines):
    d = {}
    for (lno, asm, src) in lines:
        m = ident_def_pattern.match(src)
        if m:
            name, typ = m.groups()
            d[name] = 'label' if typ == ':=' else 'symbol'
        else:
            m = label_def_pattern.match(src)
            if m:
                d[m.group(1)] = 'label'
    return d


def lint_code(lines, idents):
    for (lno, asm, src) in lines:
        if len(asm.rstrip()) < 12:      # any generated output from this line?
            continue
        if src[0] != ' ':
            lbl, *rest = src.split(None, 3)
        else:
            lbl, rest = None, src.split(None, 2)
        op, arg = (rest + [None, None])[:2]

        if op and arg and re.match(r'\w+', op):
            m = re.match(rf'(\d+|{ident})', arg)
            if m:
                name = m.group(1)
                if idents.get(name) == 'symbol' or re.match(r'\d+', name):
                    print(f"Line {lno}: symbol or constant {name} used as address")
                    print(f"    {asm}{src}")


if __name__ == "__main__":
    lst_file = sys.argv[1]

    lst_lines = open(lst_file).read().splitlines()
    #lst_lines = open("../forth-6502/forth-test.lst").read().splitlines()

    lines = strip_comments(lst_lines)

    # print('\n'.join([f"{lno}: {asm}{src}" for (lno, asm, src) in lines]))

    idents = slurp_identifiers(lines)

    # print(idents)

    lint_code(lines, idents)
