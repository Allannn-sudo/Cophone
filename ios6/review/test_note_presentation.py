import subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[2];sdk=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip();binary=root/'artifacts/ios6/test-note-presentation'
subprocess.run(['xcrun','clang','-isysroot',sdk,'-fobjc-arc','-fblocks','-Wno-deprecated-declarations','-framework','Foundation',str(root/'ios6/review/test_note_presentation.m'),str(root/'ios6/review/ReviewSession.m'),str(root/'ios6/review/ContentReader.m'),'-lsqlite3','-lz','-o',str(binary)],check=True)
subprocess.run([str(binary)],check=True)
