import { passages } from './search-results.js';

const form = document.querySelector('.search-form');
const search = form.querySelector('[name=q]');
const grid = document.querySelector('.static-episode-list');
const episodes = [...grid.querySelectorAll('[data-episode]')];
const results = document.querySelector('.static-search-results');
const count = document.querySelector('.result-count');
const status = document.querySelector('.search-status');
const more = document.querySelector('.search-more');
const order = document.querySelector('.search-order');
const batchSize = 10;
let engine;
let revision = 0;
let timer;
let matches = [];
let shown = 0;

function loadEngine() {
  if (!engine) {
    engine = import('../pagefind/pagefind.js').then(async pagefind => {
      await pagefind.options({ excerptLength: 32 });
      await pagefind.init();
      return pagefind;
    }).catch(error => { engine = null; throw error; });
  }
  return engine;
}

function element(tag, classes, text) {
  const node = document.createElement(tag);
  node.className = classes;
  if (text !== undefined) node.textContent = text;
  return node;
}

function resultRow(data) {
  const row = element('li', 'static-search-result');
  const article = element('article', 'static-search-result-content');
  const header = element('header', 'static-search-result-header');
  const title = element('h3', 'static-search-result-title');
  const link = element('a', '', data.meta.title);
  link.href = data.url;
  title.append(link);
  const metadata = [`Episode ${data.meta.number}`, data.meta.date];
  if (data.meta.collection && !data.meta.title.startsWith(`${data.meta.collection}:`)) metadata.push(data.meta.collection);
  header.append(title, element('p', 'static-search-result-meta', metadata.filter(Boolean).join(' · ')));
  const matches = element('div', 'static-search-result-matches');
  function passageRow(passage) {
    const section = element('div', 'static-search-passage');
    const time = element('a', 'static-search-time', passage.time);
    time.href = passage.href;
    time.setAttribute('aria-label', `Read and play the matching passage at ${passage.time}`);
    const excerpt = element('p', 'static-search-excerpt');
    excerpt.innerHTML = passage.excerpt; // Escaped words plus our own <mark> tags.
    section.append(time, excerpt);
    return section;
  }
  const excerpts = passages(data);
  if (excerpts.length) {
    matches.append(passageRow(excerpts[0]));
    if (excerpts.length > 1) {
      const extra = element('details', 'static-search-extra');
      extra.append(element('summary', '', `${excerpts.length - 1} more matching passage`));
      extra.append(...excerpts.slice(1).map(passageRow));
      matches.append(extra);
    }
  } else {
    // A title/metadata match is easier to scan with the episode's own synopsis.
    const excerpt = element('p', 'static-search-excerpt', data.meta.synopsis);
    if (!data.meta.synopsis) excerpt.innerHTML = data.excerpt; // Escaped by Pagefind.
    matches.append(excerpt);
  }
  article.append(header, matches);
  if (data.meta.image) {
    const poster = element('a', 'static-search-result-poster');
    poster.href = data.url;
    poster.setAttribute('aria-label', `Watch ${data.meta.title}`);
    const image = element('img', 'static-poster-image');
    image.src = data.meta.image;
    image.alt = '';
    image.loading = 'lazy';
    const play = element('span', 'static-search-poster-play');
    play.setAttribute('aria-hidden', 'true');
    poster.append(image, play, element('span', 'static-search-duration', data.meta.duration));
    article.prepend(poster);
  } else {
    article.classList.add('static-search-result-no-poster');
  }
  row.append(article);
  return row;
}

function announce(message) {
  status.textContent = message;
  status.hidden = !message;
}

async function showMore(current, focus = false) {
  more.disabled = true;
  results.setAttribute('aria-busy', 'true');
  try {
    const next = await Promise.all(matches.slice(shown, shown + batchSize).map(result => result.data()));
    if (current !== revision) return;
    const rows = next.map(resultRow);
    results.append(...rows);
    shown += next.length;
    more.hidden = shown >= matches.length;
    announce('');
    if (focus) rows[0]?.querySelector('h3 a').focus();
  } catch {
    if (current !== revision) return;
    announce('The results could not load. Try again.');
    more.hidden = false;
  } finally {
    if (current === revision) {
      more.disabled = false;
      results.setAttribute('aria-busy', 'false');
    }
  }
}

function browse() {
  grid.hidden = false;
  results.hidden = true;
  count.textContent = `${episodes.length} ${episodes.length === 1 ? 'episode' : 'episodes'}`;
  order.textContent = 'Newest first';
}

function update(updateURL = true, delay = 0) {
  const current = ++revision;
  clearTimeout(timer);
  const query = search.value.trim();
  if (updateURL) {
    const url = new URL(location.href);
    if (query) url.searchParams.set('q', query);
    else url.searchParams.delete('q');
    history.replaceState(null, '', url);
  }
  matches = [];
  shown = 0;
  results.replaceChildren();
  more.hidden = true;
  more.disabled = false;
  announce('');
  if (!query) { browse(); return; }
  grid.hidden = true;
  results.hidden = false;
  results.setAttribute('aria-busy', 'true');
  count.textContent = 'Searching…';
  order.textContent = 'Most relevant';
  timer = setTimeout(async () => {
    try {
      const pagefind = await loadEngine();
      if (current !== revision) return;
      const response = await pagefind.search(query);
      if (current !== revision) return;
      matches = response.results;
      count.textContent = `${matches.length} ${matches.length === 1 ? 'episode' : 'episodes'}`;
      if (!matches.length) {
        results.setAttribute('aria-busy', 'false');
        announce('No episodes found. Try another search.');
      } else {
        await showMore(current);
      }
    } catch {
      if (current !== revision) return;
      browse();
      announce('Search could not load. You can browse episodes below, or change your search to try again.');
    }
  }, delay);
}

function restore() {
  const url = new URL(location.href);
  search.value = url.searchParams.get('q') || '';
  // Older search links may contain a collection filter that is no longer used.
  if (url.searchParams.has('collection')) {
    url.searchParams.delete('collection');
    history.replaceState(null, '', url);
  }
  update(false);
}

form.hidden = false;
search.addEventListener('focus', () => { loadEngine().catch(() => {}); }, { once: true });
search.addEventListener('input', () => update(true, 180));
form.addEventListener('submit', event => { event.preventDefault(); update(); });
more.addEventListener('click', () => showMore(revision, true));
window.addEventListener('popstate', restore);
restore();
