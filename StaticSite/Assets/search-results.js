// Pagefind's word locations let us attach an excerpt to the preceding video cue.
// Keep this independent of the DOM so passage boundaries can be tested directly.
export function escapeHTML(value) {
  return String(value).replace(/[&<>"']/g, character => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[character]);
}

export function passages(result, limit = 2) {
  const words = result.content.split(/\s+/);
  const locations = new Set(result.locations);
  const anchors = result.anchors.filter(anchor => /^t-\d+(?:-\d+)?$/.test(anchor.id))
    .sort((a, b) => a.location - b.location);
  const weights = new Map((result.weighted_locations || []).map(hit => [hit.location, hit.balanced_score]));
  const matches = anchors.map((anchor, index) => {
    const end = anchors[index + 1]?.location ?? words.length;
    const hits = result.locations.filter(location => location >= anchor.location && location < end);
    if (!hits.length) return null;
    const best = hits.reduce((a, b) => (weights.get(b) || 1) > (weights.get(a) || 1) ? b : a);
    const start = Math.max(anchor.location, best - 8);
    const stop = Math.min(end, start + 32);
    const excerpt = (start > anchor.location ? '… ' : '') + words.slice(start, stop).map((word, offset) => {
      const escaped = escapeHTML(word);
      return locations.has(start + offset) ? `<mark>${escaped}</mark>` : escaped;
    }).join(' ') + (stop < end ? ' …' : '');
    const seconds = Number(anchor.id.split('-')[1]);
    return {
      href: `${result.url.split(/[?#]/)[0]}?t=${seconds}#${anchor.id}`,
      time: `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`,
      excerpt,
      score: hits.reduce((total, hit) => total + (weights.get(hit) || 1), 0),
      location: anchor.location,
    };
  }).filter(Boolean);
  return matches.sort((a, b) => b.score - a.score || a.location - b.location).slice(0, limit);
}
