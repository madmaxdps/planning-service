#!/usr/bin/env python3
"""Fabrique la version en ligne (GitHub Pages) : python3 build.py <Project URL> <clé anon>
Écrit le site dans deploy/site/. Ne jamais y mettre la clé service_role."""
import sys, re, shutil, pathlib, json, base64
src = pathlib.Path(__file__).resolve().parent.parent
out = src / 'deploy' / 'site'
url, key = sys.argv[1].strip().rstrip('/'), sys.argv[2].strip()
assert re.fullmatch(r'https://[a-z0-9]{20}\.supabase\.co', url), 'Project URL inattendue'
try:
    role = json.loads(base64.urlsafe_b64decode(key.split('.')[1] + '==')).get('role')
except Exception:
    role = 'publishable' if key.startswith('sb_publishable_') else None
assert role in ('anon', 'publishable'), 'Ce n\'est pas la clé anon/publishable : refus (jamais la service_role)'
host = url.split('//')[1]
csp = ("default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; "
       "font-src https://fonts.gstatic.com; img-src 'self' data: blob:; "
       f"connect-src 'self' https://{host} wss://{host} https://fonts.googleapis.com https://fonts.gstatic.com; "
       "worker-src 'self'; manifest-src 'self'; object-src 'none'; base-uri 'none'; form-action 'none'")
if out.exists(): shutil.rmtree(out)
out.mkdir(parents=True)
for f in ['manifest.webmanifest','sw.js','icon.svg','icon-192.png','icon-512.png','apple-touch-icon.png','supabase.js']:
    shutil.copy(src / f, out / f)
h = (src / 'index.html').read_text()
assert h.count("const CFG={url:'',key:''};") == 1
h = h.replace("const CFG={url:'',key:''};", f"const CFG={{url:{json.dumps(url)},key:{json.dumps(key)}}};")
h = h.replace('<meta charset="utf-8">', f'<meta charset="utf-8">\n<meta http-equiv="Content-Security-Policy" content="{csp}">\n<meta name="referrer" content="no-referrer">', 1)
(out / 'index.html').write_text(h)
(out / '.nojekyll').write_text('')
print('Site prêt :', out)
