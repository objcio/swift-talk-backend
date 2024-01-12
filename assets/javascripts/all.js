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
    
    const transcript = document.querySelector('.body.dark.episode-transcript');
    if (transcript) {
        const text = transcript.textContent;
        const keywords = ['State', 'ObservedObject', 'Binding'];
        let newText = text;
        keywords.forEach(keyword => {
            newText = newText.replace(new RegExp(`\\b${keyword}\\b`, 'g'), `<span class="swift-word-highlight">${keyword}</span>`);
        });
        newText = newText.replace(/(\d\d:\d\d)/g, (match, p1) => {
            return `<br><br><span class="timestamp">${p1}</span>`;
        });
        newText = newText.replace(/^<br><br>/, '');
        transcript.innerHTML = newText;
    }
        
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

