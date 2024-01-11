document.addEventListener("DOMContentLoaded", () => {
  var projectsBtn = document.querySelector('.swift-talk-filter-button.projects');
  var episodesBtn = document.querySelector('.swift-talk-filter-button.episodes');
  var projectsSection = document.querySelector('.swift-talk-projects-section');
  var episodesSection = document.querySelector('.swift-talk-episodes-section');

  projectsBtn.addEventListener('click', function(){
    projectsBtn.style.opacity = '1.0';
    episodesBtn.style.opacity = '0.5';

    projectsSection.style.display = 'flex';
    episodesSection.style.display = 'none';
  });

  episodesBtn.addEventListener('click', function(){
    projectsBtn.style.opacity = '0.5';
    episodesBtn.style.opacity = '1.0';

    episodesSection.style.display = 'block';
    projectsSection.style.display = 'none';
  });
});

