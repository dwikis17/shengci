# Stroke-order source snapshot

The records in `graphics-hsk1-7.txt` are taken from Make Me a Hanzi
`graphics.txt` at revision `bddc96d41bef78427ed0e034e9f7e31d71fd1b92`.

The graphics data is derived from Arphic PL KaitiM GB and Arphic PL UKai and
is redistributed under the Arphic Public License. The full license is in
`APL/ARPHICPL.TXT`; the upstream source and license details are documented in
the repository's `COPYING` file.

To regenerate the app resource after intentionally updating this snapshot:

```sh
python3 scripts/generate_stroke_order.py \
  --source scripts/stroke-order-source/graphics-hsk1-7.txt \
  --vocabulary-root shengci/Resources \
  --output shengci/Resources/stroke-order.json
```
