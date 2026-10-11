/**
 * Pulls just the holder's name out of a government ID's raw OCR text — the
 * one thing on an ID an admin cross-checks against a Business Owner
 * application. Deliberately nothing else: the ID number, birth date, and the
 * rest are sensitive and have nothing in the application to be compared
 * with, so they're never parsed, returned, or stored.
 *
 * Best-effort like `parsePermitFields`: recognises the labelled layouts of
 * the common Philippine IDs (National ID, passport, UMID — separate
 * surname / given / middle name fields; driver's license — one "Last Name,
 * First Name, Middle Name" line) plus a plain "Name:" field. An ID it can't
 * make sense of returns '' rather than a guess.
 */

// \s* between words throughout: OCR routinely drops the spaces in an ID's
// small bilingual labels ("Apelyido/LastName").
const MIDDLE = /gitnang\s*apelyido|panggitnang\s*apelyido|middle\s*name/i;
const LAST = /apelyido|last\s*name|surname/i;
const GIVEN = /mga\s*pangalan|pangalan|given\s*names?|first\s*name/i;
const COMBINED = /last\s*name\s*,\s*first\s*name/i;
const FULL = /^(?:full\s*)?name\b/i;

// A value line: letters (plus the punctuation names carry) only — this is
// what keeps a label, an ID number, or a date from being taken as a name.
const NAME_LINE = /^[a-zñ][a-zñ .,'-]*$/i;

function labelKind(line) {
  if (COMBINED.test(line)) return 'combined';
  // Middle first — "Gitnang Apelyido" also contains the surname label.
  if (MIDDLE.test(line)) return 'middle';
  if (LAST.test(line)) return 'last';
  if (GIVEN.test(line)) return 'given';
  if (FULL.test(line)) return 'full';
  return null;
}

/** The value for the label on line `i`: after a colon on that line, else the next line. */
function valueFor(lines, i) {
  const colon = lines[i].indexOf(':');
  const sameLine = colon >= 0 ? lines[i].slice(colon + 1).trim() : '';
  const candidate = sameLine || lines[i + 1] || '';
  return NAME_LINE.test(candidate) && !labelKind(candidate) ? candidate.trim() : '';
}

function parseIdName(text) {
  const lines = String(text ?? '').split(/\r?\n/).map((l) => l.trim()).filter(Boolean);
  const found = {};
  for (let i = 0; i < lines.length; i++) {
    const kind = labelKind(lines[i]);
    if (!kind || found[kind]) continue;
    const value = valueFor(lines, i);
    if (value) found[kind] = value;
  }

  let name = '';
  if (found.last || found.given) {
    name = [found.given, found.middle, found.last].filter(Boolean).join(' ');
  } else if (found.combined) {
    // "VILLARAMA, CHARISSE DELA CRUZ" → given names first, surname last.
    const [last, ...rest] = found.combined.split(',');
    name = [rest.join(' '), last].join(' ');
  } else if (found.full) {
    name = found.full;
  }
  return name.replace(/[,\s]+/g, ' ').trim().slice(0, 120);
}

module.exports = { parseIdName };
