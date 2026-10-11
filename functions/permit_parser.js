/**
 * Pulls the handful of fields an admin actually cross-checks out of a
 * business permit's raw OCR text (Vision's `fullTextAnnotation.text`).
 *
 * Best-effort by design: every LGU lays its permit out differently, so this
 * only recognises fields that sit under (or beside) a conventional label —
 * "NAME OF BUSINESS:", "BUSINESS OWNER:", and so on. Anything it can't find
 * comes back as an empty string rather than a guess; the raw text is still
 * stored alongside, and the admin still looks at the actual photo.
 */

const MONTHS = [
  'january', 'february', 'march', 'april', 'may', 'june',
  'july', 'august', 'september', 'october', 'november', 'december',
];

const LABELS = {
  businessName: /^(?:registered\s+)?(?:name\s+of\s+(?:the\s+)?business|business\s*(?:\/\s*trade)?\s+name|trade\s+name)\b/i,
  ownerName: /^(?:business\s+owner|name\s+of\s+(?:the\s+)?(?:owner|proprietor|taxpayer)|owner(?:'?s)?(?:\s+name)?|proprietor|taxpayer(?:'?s)?(?:\s+name)?)\b/i,
  address: /^(?:business\s+address|address\s+of\s+(?:the\s+)?business|location\s+of\s+business|business\s+location|address)\b/i,
  permitNo: /^(?:business\s+|mayor'?s\s+)?permit\s*(?:no|number|#)\.?/i,
};

// A line starting with any of these ends the value above it — the next
// field's own label, or boilerplate that commonly follows the last field.
const STOP = [
  ...Object.values(LABELS),
  /^(?:nature|kind|line|type)\s+of\s+(?:business|permit)\b/i,
  /^(?:date\s+issued|issued\s+on|classification|permit\s+validity|validity|valid\s+until|expir)/i,
  /^(?:this\s+(?:permit|certifies)|not\s+valid|official|republic\s+of|province\s+of|office\s+of|(?:municipality|city)\s+of)\b/i,
];

const isStop = (line) => STOP.some((re) => re.test(line));

/**
 * The value belonging to the first line matching `label`: whatever follows
 * the label on that same line, else the next `maxLines` lines up to the
 * next label/boilerplate line.
 */
function valueAfterLabel(lines, label, maxLines) {
  for (let i = 0; i < lines.length; i++) {
    const match = lines[i].match(label);
    if (!match) continue;
    const sameLine = lines[i].slice(match[0].length).replace(/^[\s:.\-–—]+/, '').trim();
    const parts = sameLine ? [sameLine] : [];
    for (let j = i + 1; j < lines.length && parts.length < maxLines; j++) {
      if (isStop(lines[j])) break;
      parts.push(lines[j]);
    }
    if (parts.length) return parts.join(' ').replace(/\s+/g, ' ').trim();
  }
  return '';
}

/** Every date found in `text`, in order, as `YYYY-MM-DD` strings. */
function findDates(text) {
  const found = [];
  const named = new RegExp(`\\b(${MONTHS.join('|')})\\.?\\s+(\\d{1,2})\\s*,?\\s*(\\d{4})\\b`, 'gi');
  for (const m of text.matchAll(named)) {
    found.push({ index: m.index, iso: toIso(Number(m[3]), MONTHS.indexOf(m[1].toLowerCase()) + 1, Number(m[2])) });
  }
  // Numeric dates are read month-first, the order Philippine paperwork uses.
  for (const m of text.matchAll(/\b(\d{1,2})[/-](\d{1,2})[/-](\d{4})\b/g)) {
    found.push({ index: m.index, iso: toIso(Number(m[3]), Number(m[1]), Number(m[2])) });
  }
  return found.filter((d) => d.iso).sort((a, b) => a.index - b.index).map((d) => d.iso);
}

function toIso(year, month, day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return '';
  return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
}

/**
 * The permit's last day of validity. A validity block reads "JANUARY 1,
 * 2026 TO DECEMBER 31, 2026", so the *latest* date near the label is the
 * end of the range; a "renewed on or before" line is the fallback.
 */
function findValidUntil(text) {
  const label = text.search(/permit\s+validity|valid(?:ity)?\s+(?:until|up\s+to|period)|\bvalidity\b|expir(?:y|ation|es)/i);
  if (label >= 0) {
    const dates = findDates(text.slice(label, label + 160));
    if (dates.length) return dates.sort().at(-1);
  }
  const renew = text.search(/renew(?:ed|al)?\s+on\s+or\s+before/i);
  if (renew >= 0) {
    const dates = findDates(text.slice(renew, renew + 80));
    if (dates.length) return dates[0];
  }
  return '';
}

/** e.g. "Municipality of Baliwag, Bulacan" — whichever parts are present. */
function findIssuingLgu(lines) {
  const titleCase = (s) => s.toLowerCase().replace(/\b[a-z]/g, (c) => c.toUpperCase()).replace(/\bOf\b/g, 'of');
  const pick = (re) => {
    for (const line of lines) {
      const m = line.match(re);
      if (m) return titleCase(m[0].replace(/\s+/g, ' ').trim());
    }
    return '';
  };
  const lgu = pick(/^(?:municipality|city)\s+of\s+[a-zñ .'-]{2,40}$/i);
  const province = pick(/^province\s+of\s+[a-zñ .'-]{2,40}$/i).replace(/^Province of\s+/, '');
  return [lgu, province].filter(Boolean).join(', ');
}

function parsePermitFields(text) {
  const lines = String(text ?? '').split(/\r?\n/).map((l) => l.trim()).filter(Boolean);
  const joined = lines.join('\n');

  let permitNo = valueAfterLabel(lines, LABELS.permitNo, 1);
  // The number often sits in its own box away from its label, so OCR can
  // emit something else right after "PERMIT NO." — only keep a value that
  // actually looks like a permit number, else fall back to the usual
  // YYYY-NNNN shape anywhere in the text.
  if (!/\d/.test(permitNo) || permitNo.length > 30) {
    permitNo = joined.match(/\b\d{4}\s?-\s?\d{3,7}\b/)?.[0].replace(/\s/g, '') ?? '';
  }

  return {
    businessName: valueAfterLabel(lines, LABELS.businessName, 1),
    ownerName: valueAfterLabel(lines, LABELS.ownerName, 1),
    address: valueAfterLabel(lines, LABELS.address, 3),
    permitNo,
    validUntil: findValidUntil(joined),
    issuingLgu: findIssuingLgu(lines),
  };
}

module.exports = { parsePermitFields };
