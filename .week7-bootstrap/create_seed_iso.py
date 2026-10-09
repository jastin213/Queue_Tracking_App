import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "vendor"))

import pycdlib


iso = pycdlib.PyCdlib()
iso.new(interchange_level=3, joliet=3, rock_ridge="1.09", vol_ident="CIDATA")
iso.add_file(
    str(ROOT / "user-data"),
    iso_path="/USER_DATA.;1",
    joliet_path="/user-data",
    rr_name="user-data",
)
iso.add_file(
    str(ROOT / "meta-data"),
    iso_path="/META_DATA.;1",
    joliet_path="/meta-data",
    rr_name="meta-data",
)
iso.write(str(ROOT / "seed.iso"))
iso.close()
print(ROOT / "seed.iso")
