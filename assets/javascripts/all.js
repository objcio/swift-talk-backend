document.addEventListener("DOMContentLoaded", () => {
    var projectsBtn = document.querySelector('.swift-talk-filter-button.projects');
    var episodesBtn = document.querySelector('.swift-talk-filter-button.episodes');
    var projectsSection = document.querySelector('.swift-talk-projects-section');
    var episodesSection = document.querySelector('.swift-talk-episodes-section');
    
    projectsBtn?.addEventListener('click', function(){
        projectsBtn.style.opacity = '1.0';
        episodesBtn.style.opacity = '0.5';
        
        projectsSection.style.display = 'flex';
        episodesSection.style.display = 'none';
    });
    
    episodesBtn?.addEventListener('click', function(){
        projectsBtn.style.opacity = '0.5';
        episodesBtn.style.opacity = '1.0';
        
        episodesSection.style.display = 'block';
        projectsSection.style.display = 'none';
    });
    
//    const transcript = document.querySelector('.body.dark.episode-transcript');
//    if (transcript) {
//        const text = transcript.textContent;
////        const keywords = ['State', 'ObservedObject', 'Binding'];
//        let newText = text;
////        keywords.forEach(keyword => {
////            newText = newText.replace(new RegExp(`\\b${keyword}\\b`, 'g'), `<span class="swift-word-highlight">${keyword}</span>`);
////        });
//        newText = newText.replace(/(\d\d:\d\d)/g, (match, p1) => {
//            return `<br><br><span class="timestamp">${p1}</span>`;
//        });
//        newText = newText.replace(/^<br><br>/, '');
//        transcript.innerHTML = newText;
//    }
        
});

var Webflow = Webflow || [];
Webflow.push(function () {
    var learnDropdownToggle = document.querySelector('.footer-dropdown-toggle.learn');
    var learnOpenImage = document.querySelector('.dropdown-open-image.learn');
    var learnClosedImage = document.querySelector('.dropdown-closed-image.learn');
    var connectDropdownToggle = document.querySelector('.footer-dropdown-toggle.connect');
    var connectOpenImage = document.querySelector('.dropdown-open-image.connect');
    var connectClosedImage = document.querySelector('.dropdown-closed-image.connect');
    var moreDropdownToggle = document.querySelector('.footer-dropdown-toggle.more');
    var moreOpenImage = document.querySelector('.dropdown-open-image.more');
    var moreClosedImage = document.querySelector('.dropdown-closed-image.more');
    learnDropdownToggle?.addEventListener('click', function() {
        const learnOpenImageStyle = getComputedStyle(learnOpenImage);
        const learnOpenImageDisplay = learnOpenImageStyle.display;
        if (learnOpenImageDisplay === 'block') {
            learnOpenImage.style.display = 'none';
            learnClosedImage.style.display = 'block';
        } else if (learnOpenImageDisplay === 'none') {
            learnOpenImage.style.display = 'block';
            learnClosedImage.style.display = 'none';
        }
        connectClosedImage.style.display = 'block';
        connectOpenImage.style.display = 'none';
        moreClosedImage.style.display = 'block';
        moreOpenImage.style.display = 'none';
    });
    connectDropdownToggle?.addEventListener('click', function() {
        const connectOpenImageStyle = getComputedStyle(connectOpenImage);
        const connectOpenImageDisplay = connectOpenImageStyle.display;
        if (connectOpenImageDisplay === 'block') {
            connectOpenImage.style.display = 'none';
            connectClosedImage.style.display = 'block';
        } else if (connectOpenImageDisplay === 'none') {
            connectOpenImage.style.display = 'block';
            connectClosedImage.style.display = 'none';
        }
        learnClosedImage.style.display = 'block';
        learnOpenImage.style.display = 'none';
        moreClosedImage.style.display = 'block';
        moreOpenImage.style.display = 'none';
    });
    moreDropdownToggle?.addEventListener('click', function() {
        const moreOpenImageStyle = getComputedStyle(moreOpenImage);
        const moreOpenImageDisplay = moreOpenImageStyle.display;
        if (moreOpenImageDisplay === 'block') {
            moreOpenImage.style.display = 'none';
            moreClosedImage.style.display = 'block';
        } else if (moreOpenImageDisplay === 'none') {
            moreOpenImage.style.display = 'block';
            moreClosedImage.style.display = 'none';
        }
        connectClosedImage.style.display = 'block';
        connectOpenImage.style.display = 'none';
        learnClosedImage.style.display = 'block';
        learnOpenImage.style.display = 'none';
    });
});

const pSBC=(p,c0,c1,l)=>{
    let r,g,b,P,f,t,h,i=parseInt,m=Math.round,a=typeof(c1)=="string";
    if(typeof(p)!="number"||p<-1||p>1||typeof(c0)!="string"||(c0[0]!='r'&&c0[0]!='#')||(c1&&!a))return null;
    if(!this.pSBCr)this.pSBCr=(d)=>{
        let n=d.length,x={};
        if(n>9){
            [r,g,b,a]=d=d.split(","),n=d.length;
            if(n<3||n>4)return null;
            x.r=i(r[3]=="a"?r.slice(5):r.slice(4)),x.g=i(g),x.b=i(b),x.a=a?parseFloat(a):-1
        }else{
            if(n==8||n==6||n<4)return null;
            if(n<6)d="#"+d[1]+d[1]+d[2]+d[2]+d[3]+d[3]+(n>4?d[4]+d[4]:"");
            d=i(d.slice(1),16);
            if(n==9||n==5)x.r=d>>24&255,x.g=d>>16&255,x.b=d>>8&255,x.a=m((d&255)/0.255)/1000;
            else x.r=d>>16,x.g=d>>8&255,x.b=d&255,x.a=-1
        }return x};
    h=c0.length>9,h=a?c1.length>9?true:c1=="c"?!h:false:h,f=this.pSBCr(c0),P=p<0,t=c1&&c1!="c"?this.pSBCr(c1):P?{r:0,g:0,b:0,a:-1}:{r:255,g:255,b:255,a:-1},p=P?p*-1:p,P=1-p;
    if(!f||!t)return null;
    if(l)r=m(P*f.r+p*t.r),g=m(P*f.g+p*t.g),b=m(P*f.b+p*t.b);
    else r=m((P*f.r**2+p*t.r**2)**0.5),g=m((P*f.g**2+p*t.g**2)**0.5),b=m((P*f.b**2+p*t.b**2)**0.5);
    a=f.a,t=t.a,f=a>=0||t>=0,a=f?a<0?t:t<0?a:a*P+t*p:0;
    if(h)return"rgb"+(f?"a(":"(")+r+","+g+","+b+(f?","+m(a*1000)/1000:"")+")";
    else return"#"+(4294967296+r*16777216+g*65536+b*256+(f?m(a*255):0)).toString(16).slice(1,f?undefined:-2)
}
