"""Romanised Tanglish -> Kokoro phonemes (IPA subset in Kokoro's vocab).

Kokoro's English/Hindi G2P mangles Tamil words ("dhaan" -> "dihaan"). We detect Tamil words
(explicit set, or lowercase words unknown to the English lexicon) and convert them with simple
spelling rules; everything else goes through Kokoro's own G2P.
"""
import re

TAMIL = set("""anna naan dhaan dhaana amma appa kanna nee po vara enga ennai thedi yaara venaalum nambu aana andha
oru vishayam kandupidichiruken solla mudiyaadhu inga vandhappo edhavadhu irundha irundhu kitta mattum pesu
saaptiya saapten moonji ellam ilachu pochu moonu naala mela kovama irukkaala irukkaa irukkiradhu
eduthutu kadai nalla poguthu kavala padaadhenu sonnaarnu sollu veetuku veetu innoru ponnu anupparen paaru
ippo venaam varaadha vandhudu panna pannadha maadhiri ku la nu naam
enna vandhaa vela prachanaiya""".split())
NAMES = {"preethi": "pɹˈiːðiː", "pongal": "pˈoŋɡɐl", "nila": "nˈiːlɐ", "mani": "mˈɐɳi"}

RULES = [("aa", "ɑː"), ("ee", "iː"), ("ii", "iː"), ("oo", "uː"), ("ai", "ɑɪ"), ("au", "ɑʊ"),
         ("zh", "ɻ"), ("dh", "d"), ("th", "t"), ("ch", "ʧ"), ("sh", "ʃ"), ("ng", "ŋ"),
         ("a", "ɐ"), ("e", "e"), ("i", "i"), ("o", "o"), ("u", "u"),
         ("j", "ʤ"), ("r", "ɾ"), ("v", "v"), ("y", "j"), ("w", "w")]


def tamil_ipa(word: str) -> str:
    w = word.lower()
    if w in NAMES:
        return NAMES[w]
    w = re.sub(r"(.)\1+", lambda m: m.group(1) * (1 if m.group(1) in "bcdfghjklmnpqrstvwxyz" else 2), w)
    out, i = [], 0
    while i < len(w):
        for src, dst in RULES:
            if w.startswith(src, i):
                out.append(dst); i += len(src); break
        else:
            out.append(w[i]); i += 1
    s = "".join(out)
    m = re.search(r"[ɐeiouɑ]", s)
    return (s[:m.start()] + "ˈ" + s[m.start():]) if m else s


def is_tamil(word: str, english_lexicon) -> bool:
    w = word.lower()
    if w in TAMIL or w in NAMES:
        return True
    return word.islower() and w not in english_lexicon and len(w) > 2 and not word.isupper()


def split_runs(text: str, english_lexicon):
    """Yield ('en', text) / ('ta', ipa) / ('p', punctuation) runs."""
    runs, buf = [], []
    def flush():
        if buf:
            runs.append(("en", " ".join(buf))); buf.clear()
    for tok in re.findall(r"[A-Za-z']+|[^A-Za-z'\s]", text):
        if re.match(r"[A-Za-z']", tok):
            if is_tamil(tok, english_lexicon):
                flush(); runs.append(("ta", tamil_ipa(tok)))
            else:
                buf.append(tok)
        elif tok == "-":
            continue
        else:
            flush(); runs.append(("p", tok))
    flush()
    return runs
