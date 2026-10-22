"""Orthogonal routing shared by editable diagrams, SVG previews and layout checks."""
import heapq
import math


def rect(n, padding=0):
    return (n['x']-padding, n['y']-padding,
            n['x']+n['w']+padding, n['y']+n['h']+padding)


def hits(a, b, r):
    left, top, right, bottom = r
    if a[0] == b[0]:
        return left < a[0] < right and max(min(a[1], b[1]), top) < min(max(a[1], b[1]), bottom)
    return top < a[1] < bottom and max(min(a[0], b[0]), left) < min(max(a[0], b[0]), right)


def interaction(a, b, c, d):
    horizontal = a[1] == b[1]
    other_horizontal = c[1] == d[1]
    if horizontal == other_horizontal:
        axis = 0 if horizontal else 1
        fixed = 1-axis
        if a[fixed] != c[fixed]:
            return 0
        overlap = min(max(a[axis], b[axis]), max(c[axis], d[axis])) - max(min(a[axis], b[axis]), min(c[axis], d[axis]))
        return 100000 + overlap*100 if overlap > .01 else 0
    if not horizontal:
        a, b, c, d = c, d, a, b
    return 200 if min(a[0], b[0]) < c[0] < max(a[0], b[0]) and min(c[1], d[1]) < a[1] < max(c[1], d[1]) else 0


def simplify(points):
    out = []
    for p in points:
        if out and out[-1] == p:
            continue
        if len(out) > 1 and ((out[-2][0] == out[-1][0] == p[0]) or
                             (out[-2][1] == out[-1][1] == p[1])):
            out.pop()
        out.append(p)
    return out


def route_page(page):
    connected = [e for e in page.edges if e['source'] and e['target'] and not e.get('locked')]
    if not connected:
        return
    lookup = {n['id']: n for n in page.nodes}
    obstacles = [rect(n, 5) for n in page.nodes
                 if n['kind'] not in ('title', 'subtitle', 'frame', 'fragment')]
    obstacles += [(n['x'],n['y'],n['x']+n['w'],n['y']+32)
                  for n in page.nodes if n['kind'] == 'frame' and n['text']]
    counts = {}
    ports = []
    for e in connected:
        a, b = lookup[e['source']], lookup[e['target']]
        dx = b['x']+b['w']/2-a['x']-a['w']/2
        dy = b['y']+b['h']/2-a['y']-a['h']/2
        if dx == 0:
            sides = ('right', 'right')
        elif abs(dx) > abs(dy):
            sides = ('right', 'left') if dx > 0 else ('left', 'right')
        else:
            sides = ('bottom', 'top') if dy > 0 else ('top', 'bottom')
        pair = []
        for n, side in zip((a, b), sides):
            key = (n['id'], side)
            index = counts.get(key, 0)
            counts[key] = index+1
            pair.append((n, side, index))
        ports.append(pair)
    endpoints = []
    for pair in ports:
        result = []
        for n, side, index in pair:
            fraction = (index+1)/(counts[(n['id'], side)]+1)
            if side in ('left', 'right'):
                x = n['x'] + (n['w'] if side == 'right' else 0)
                y = round(n['y']+n['h']*fraction, 2)
                stub = (x+(9 if side == 'right' else -9), y)
                if n['kind'] == 'actor':
                    y = round(n['y']+32+35*fraction, 2)
                    x = n['x']+n['w']/2
                    stub = (stub[0],y)
                elif n['kind'] == 'oval':
                    radius = n['w']/2*math.sqrt(1-(2*fraction-1)**2)
                    x = n['x']+n['w']/2+(radius if side == 'right' else -radius)
            else:
                x = round(n['x']+n['w']*fraction, 2)
                y = n['y']+(n['h'] if side == 'bottom' else 0)
                stub = (x, y+(9 if side == 'bottom' else -9))
                if n['kind'] == 'oval':
                    radius = n['h']/2*math.sqrt(1-(2*fraction-1)**2)
                    y = n['y']+n['h']/2+(radius if side == 'bottom' else -radius)
            result.append(((x, y), stub, ((x-n['x'])/n['w'], (y-n['y'])/n['h'])))
        endpoints.append(result)
    xs = {18, page.width-18}
    ys = {118, page.height-18}
    for r in obstacles:
        xs.update((r[0]-5, r[2]+5))
        ys.update((r[1]-5, r[3]+5))
    for pair in endpoints:
        for point, stub, anchor in pair:
            xs.add(stub[0]); ys.add(stub[1])
    xs = sorted(x for x in xs if 0 < x < page.width)
    ys = sorted(y for y in ys if 110 < y < page.height)
    xindex, yindex = {v:i for i,v in enumerate(xs)}, {v:i for i,v in enumerate(ys)}
    legal = {}
    used = [(a,b) for e in page.edges if e.get('locked')
            for a,b in zip(e['points'],e['points'][1:])]
    for e, pair in zip(connected, endpoints):
        (start, s, sa), (end, t, ta) = pair
        source, target = (xindex[s[0]], yindex[s[1]]), (xindex[t[0]], yindex[t[1]])
        initial = (*source, -1)
        queue = [(0, 0, initial)]
        distance, previous = {initial: 0}, {}
        serial = 0
        final = None
        while queue:
            _, _, state = heapq.heappop(queue)
            ix, iy, direction = state
            if (ix, iy) == target:
                final = state
                break
            a = (xs[ix], ys[iy])
            for nx, ny, nd in ((ix-1, iy, 0), (ix+1, iy, 0), (ix, iy-1, 1), (ix, iy+1, 1)):
                if not (0 <= nx < len(xs) and 0 <= ny < len(ys)):
                    continue
                b = (xs[nx], ys[ny])
                key = tuple(sorted((a,b)))
                if key not in legal:
                    legal[key] = not any(hits(a, b, r) for r in obstacles)
                if not legal[key]:
                    continue
                penalty = sum(interaction(a,b,c,d) for c,d in used)
                score = distance[state]+abs(a[0]-b[0])+abs(a[1]-b[1])+penalty+(18 if direction not in (-1, nd) else 0)
                ns = (nx, ny, nd)
                if score >= distance.get(ns, math.inf):
                    continue
                distance[ns], previous[ns] = score, state
                serial += 1
                heuristic = abs(b[0]-t[0])+abs(b[1]-t[1])
                heapq.heappush(queue, (score+heuristic, serial, ns))
        if final is None:
            raise ValueError(f'No route: {page.code} {e["source"]} -> {e["target"]}')
        path = []
        while final != initial:
            path.append((xs[final[0]], ys[final[1]]))
            final = previous[final]
        path.append(s)
        path.reverse()
        e['points'] = simplify([start]+path+[end])
        e['anchors'] = (*sa, *ta)
        used.extend(zip(e['points'], e['points'][1:]))


def bridge_path(points, prior):
    """Visible arcs distinguish crossings; shared collinear paths are audited separately."""
    path = f'M{points[0][0]},{points[0][1]}'
    for a,b in zip(points, points[1:]):
        horizontal = a[1] == b[1]
        crossings = []
        for c,d in prior:
            if interaction(a,b,c,d) != 200:
                continue
            v = c[0] if horizontal else c[1]
            if min(a[0 if horizontal else 1], b[0 if horizontal else 1])+7 < v < max(a[0 if horizontal else 1], b[0 if horizontal else 1])-7:
                crossings.append(v)
        axis = 0 if horizontal else 1
        sign = 1 if b[axis] > a[axis] else -1
        for v in sorted(set(crossings), reverse=sign < 0):
            if horizontal:
                path += f' L{v-sign*5},{a[1]} Q{v},{a[1]-9} {v+sign*5},{a[1]}'
            else:
                path += f' L{a[0]},{v-sign*5} Q{a[0]+9},{v} {a[0]},{v+sign*5}'
        path += f' L{b[0]},{b[1]}'
    return path
