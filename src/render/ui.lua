local U = {buttons={}, fonts={}, scale=1, ox=0, oy=0}
U.c = {
  bg={0.035,0.045,0.090},panel={0.073,0.090,0.149},raised={0.105,0.126,0.201},
  border={0.18,0.21,0.30},text={0.91,0.93,0.96},muted={0.52,0.59,0.70},
  mint={0.44,0.88,0.73},gold={1,0.79,0.42},coral={1,0.48,0.47},purple={0.66,0.57,0.97}
}
function U.init()
  for _,size in ipairs({11,12,13,14,15,16,18,20,22,24,28,32,40,48,64,76}) do
    U.fonts[size]=love.graphics.newFont(size)
    U.fonts[size]:setFilter('linear','linear')
  end
end
function U.begin() U.buttons={} end
function U.color(c,a) love.graphics.setColor(c[1],c[2],c[3],a or c[4] or 1) end
function U.rect(x,y,w,h,c,r) U.color(c); love.graphics.rectangle('fill',x,y,w,h,r or 0,r or 0) end
function U.line(x1,y1,x2,y2,c) U.color(c);love.graphics.line(x1,y1,x2,y2) end
function U.text(s,x,y,size,c,w,align)
  love.graphics.setFont(U.fonts[size or 16] or U.fonts[16]); U.color(c or U.c.text)
  if w then love.graphics.printf(tostring(s),x,y,w,align or 'left') else love.graphics.print(tostring(s),x,y) end
end
function U.panel(x,y,w,h,raised)
  U.rect(x,y,w,h,raised and U.c.raised or U.c.panel,12)
  U.color(U.c.border,0.65);love.graphics.rectangle('line',x+.5,y+.5,w-1,h-1,12,12)
end
function U.pill(s,x,y,c,w)
  w=w or (U.fonts[12]:getWidth(s)+20)
  U.rect(x,y,w,24,{c[1],c[2],c[3],0.14},7);U.text(s,x,y+4,12,c,w,'center')
end
function U.button(label,x,y,w,h,fn,options)
  options=options or {};local mx,my=love.mouse.getPosition(); mx=(mx-U.ox)/U.scale;my=(my-U.oy)/U.scale
  local hover=mx>=x and my>=y and mx<=x+w and my<=y+h
  local selected=options.selected; local disabled=options.disabled
  local fill=options.fill or ((hover or selected) and U.c.raised or U.c.panel)
  U.rect(x,y,w,h,fill,options.radius or 9)
  U.color(selected and U.c.mint or U.c.border,disabled and .3 or 1)
  love.graphics.rectangle('line',x+.5,y+.5,w-1,h-1,options.radius or 9,options.radius or 9)
  U.text(label,x+8,y+(h-(options.size or 16))/2-2,options.size or 16,disabled and U.c.muted or options.color or U.c.text,w-16,options.align or 'center')
  if not disabled then U.buttons[#U.buttons+1]={x=x,y=y,w=w,h=h,fn=fn} end
end
function U.click(x,y)
  for i=#U.buttons,1,-1 do local b=U.buttons[i];if x>=b.x and y>=b.y and x<=b.x+b.w and y<=b.y+b.h then b.fn();return true end end
end
function U.bar(x,y,w,h,amount,c,background)
  U.rect(x,y,w,h,background or U.c.raised,h/2)
  if amount>0 then U.rect(x,y,math.max(h, w*math.min(1,amount)),h,c,h/2) end
end
function U.clip(x,y,w,h) love.graphics.setScissor(math.floor(U.ox+x*U.scale),math.floor(U.oy+y*U.scale),math.ceil(w*U.scale),math.ceil(h*U.scale)) end
function U.unclip() love.graphics.setScissor() end
function U.count(t) local n=0;for _ in pairs(t or {}) do n=n+1 end;return n end
function U.hpColor(ratio) return ratio>.5 and U.c.mint or ratio>.2 and U.c.gold or U.c.coral end
return U
