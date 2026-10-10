from pathlib import Path
from collections import deque

P = Path(__file__).resolve().parent
W,H=64,48
scenes=['disk']*4+['blank']*4+['square','bar','red','green','blue','y200']+['y201']*4+['yellow','cyan','merge','diagonal','edge','two','noise','malformed']+['disk']*4
def pixels(scene):
    out=[]
    for y in range(H):
        for x in range(W):
            disk=(x-32)**2+(y-24)**2<=10**2
            fg=disk
            if scene=='blank': fg=False
            if scene=='square': fg=22<=x<=41 and 14<=y<=33
            if scene=='bar': fg=4<=x<=59 and 22<=y<=25
            if scene=='merge': fg=(x in range(20,25) or x in range(35,40)) and 8<=y<30 or 20<=x<40 and 25<=y<30
            if scene=='diagonal': fg=(x==y and 5<=x<35)
            if scene=='edge': fg=x*x+(y-24)**2<=100
            if scene=='two': fg=(x-16)**2+(y-24)**2<=64 or (x-48)**2+(y-24)**2<=64
            if scene=='noise': fg=(x%4==0 and y%4==0)
            color={'red':(255,0,0),'green':(0,255,0),'blue':(0,0,255),'y200':(200,200,200),'y201':(201,201,201),'yellow':(255,255,0),'cyan':(0,255,255)}.get(scene,(255,255,255))
            out.append(color if fg else (0,0,0))
    return out
def oracle(rgb):
    fg={(i%W,i//W) for i,(r,g,b) in enumerate(rgb) if (77*r+150*g+29*b)>>8 >200}
    components=[]
    while fg:
        seed=min(fg,key=lambda p:(p[1],p[0])); fg.remove(seed)
        q=deque([seed]); c={seed}
        while q:
            x,y=q.popleft()
            for p in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
                if p in fg:fg.remove(p); c.add(p); q.append(p)
        area=len(c); xs=[p[0] for p in c]; ys=[p[1] for p in c]
        perim=sum((x+dx,y+dy) not in c for x,y in c for dx,dy in [(-1,0),(1,0),(0,-1),(0,1)])
        components.append((area,perim,min(xs),max(xs),min(ys),max(ys)))
    return components

vectors=[]; golden=[]; stats=[]; ball=0; streak=0
def clock(data=0,valid=0,user=0,last=0):
    vectors.append((data<<3)|(valid<<2)|(user<<1)|last)
for scene in scenes:
    rgb=pixels(scene); cs=oracle(rgb); invalid=scene in ('noise','malformed')
    hit=any(20<=a<=2000 and 65*(x1-x0+1)*(y1-y0+1)<=100*a<=90*(x1-x0+1)*(y1-y0+1) and 100*(x1-x0+1)>=75*(y1-y0+1) and 100*(y1-y0+1)>=75*(x1-x0+1) and p*p<=24*a for a,p,x0,x1,y0,y1 in cs)
    if invalid:ball=0;streak=0;hit=False
    elif hit==ball:streak=0
    elif streak==3:ball=int(hit);streak=0
    else:streak+=1
    golden.append((int(invalid)<<3)|(int(hit)<<2)|(ball<<1))
    stats.append(cs)
    clock(user=1)
    for _ in range(60):clock()
    for y in range(H):
        row=bytes(v for pix in rgb[y*W:(y+1)*W] for v in pix)
        if scene=='malformed' and y==0: row=row[:48]
        for i in range(len(row)//16):
            clock(int.from_bytes(row[16*i:16*i+16],'big'),1,0,int(i==len(row)//16-2))
            if i%3==2:clock()
        for _ in range(850):clock()
    for _ in range(800):clock()
clock(user=1)
for _ in range(30000):clock()
(P/'vectors.hex').write_text('\n'.join(f'{v:033x}' for v in vectors)+'\n')
(P/'golden.hex').write_text('\n'.join(f'{v:x}' for v in golden)+'\n')
packed=[]
for cs in stats:
    for a,p,x0,x1,y0,y1 in cs[:63]:
        packed.append((a<<68)|(p<<44)|(x0<<33)|(x1<<22)|(y0<<11)|y1)
    packed.extend([0]*(64-min(len(cs),63)))
(P/'stats.hex').write_text('\n'.join(f'{v:023x}' for v in packed)+'\n')
(P/'vector_config.vh').write_text(f'`define NCLOCKS {len(vectors)}\n`define NFRAMES {len(scenes)}\n')
print('Frames:',len(scenes),'clocks:',len(vectors),list(zip(scenes,golden)))
