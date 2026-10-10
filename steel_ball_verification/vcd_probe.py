import re, sys

def load(path):
    ids = {}
    lines = open(path, encoding='latin1').read().splitlines()
    i = 0; n = len(lines)
    while i < n:
        ln = lines[i]
        m = re.match(r'\$var\s+\w+\s+(\d+)\s+([!-~]+)\s+(\S+)', ln)
        if m:
            ids[m.group(2)] = (int(m.group(1)), m.group(3))
        if ln.startswith('$enddefinitions'):
            break
        i += 1
    return ids

def main(path):
    ids = load(path)  # code -> (width, name)
    code2 = {c: nm for c, (w, nm) in ids.items()}
    lines = open(path, encoding='latin1').read().splitlines()
    i = 0; n = len(lines)
    # skip header
    while i < n:
        if lines[i].startswith('$enddefinitions'):
            i += 1; break
        i += 1
    state = {}
    time = 0
    records = []  # (time, state-snapshot)
    while i < n:
        ln = lines[i].strip()
        if not ln:
            i += 1; continue
        if ln.startswith('#'):
            time = int(ln[1:])
            records.append((time, dict(state)))
            i += 1; continue
        if ln.startswith('b') or ln.startswith('B'):
            parts = ln.split()
            nm = code2.get(parts[1])
            if nm:
                bits = parts[0][1:]
                val = int(bits.replace('x','0').replace('X','0').replace('z','0').replace('Z','0'), 2)
                state[nm] = val
            i += 1; continue
        if len(ln) >= 2 and ln[0] in '01xXzZ':
            nm = code2.get(ln[1:])
            if nm:
                state[nm] = 1 if ln[0] == '1' else 0
            i += 1; continue
        if ln in ('$dumpvars','$end','$dumpoff','$dumpon'):
            i += 1; continue
        i += 1

    # sample at posedges: clk period 10000ps, rises at t%10000==5000
    names = ['S_AXIS_tdata','S_AXIS_tvalid','S_AXIS_tuser','S_AXIS_tlast',
             'phase','mask2','mask2_reg','dd0','dd1','dd2','pdp3',
             'ov_data','ov_valid','carry','M_AXIS_tvalid']
    idx = 0
    print("records:", len(records))
    for t, s in records:
        if t % 10000 == 5000:
            def g(nm, w=32):
                v = s.get(nm)
                if v is None: return '-'
                return f'{(v & ((1<<w)-1)):0{w//4}x}' if w in (32,128,16) else str(v)
            def bb(nm, bits=6):
                v = s.get(nm)
                return f'{v:0{bits}b}' if v is not None else '-'
            print(f"t={t//1000:5d}ns in={g('S_AXIS_tdata',128)[16:]} v={g('S_AXIS_tvalid')} u={g('S_AXIS_tuser')} "
                  f"ph={g('phase')} m2={bb('mask2')} mr={bb('mask2_reg')} dd2={g('dd2',128)[16:]} "
                  f"p3={g('pdp3')} ovv={g('ov_valid')}")
            idx += 1
            if idx > 24: break

main(sys.argv[1])
