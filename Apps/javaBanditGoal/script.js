console.log("VALUABLE RESEARCH NEEDS VALUABLE DATA. PLEASE DON'T CHEAT! \nIf you do please answer in the questionnaire honestly that you did so\nthat we can make sure to not use your data.\nThank you!");Shiny.addCustomMessageHandler("envHandler",function(a){a=JSON.parse(JSON.stringify(a));eno=a.eno;ent=a.ent;ens=a.ens;env=a.env;nTrials=a.nTrials;gameNr=[a.game];goal=a.goal});
function endGame(a,c,d,f,h,e){Shiny.onInputChange("selection",a);Shiny.onInputChange("outcome",c);Shiny.onInputChange("outcomeCum",d);Shiny.onInputChange("respTime",f);Shiny.onInputChange("trial",h);Shiny.onInputChange("gameNr",e)}function newGame(){ind=[];selection=[];outcome=[];outcomeCum=[];t=(new Date).getTime();respTime=[];trial=[]}function add(a,c){return a+c}
function updateValue(a,c,d,f,h,e,w,x,b,q,k,l,m,n,p,g,r,u,v){b.length<n&&(0===b.length?g.push((new Date).getTime()-u):g.push((new Date).getTime()-g[g.length-1]),a=document.getElementById(a),c=document.getElementById(c),d=document.getElementById(d),f=document.getElementById(f),h=0===e[b.length]?"#BEBEBE":0>e[b.length]?"#FF6A6A":"#00CD00",a.innerHTML=e[b.length],a.style.color=h,m[m.lenth]!=q&&(c.innerHTML=" "),m.push(q),k.push(e[b.length]),k.reduce(add,0)<v?d.style.color="#FF6A6A":d.style.color="#00CD00",
r.push(b.length+1),f.innerHTML=n-(b.length+1),l.push(k.reduce(add,0)),b.push(1),p.length<n&&p.push(p[0]),d.innerHTML=l[l.length-1],b.length===n&&endGame(m,k,l,g,r,p))};