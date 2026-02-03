# pip install pypi-attestations
pip install git+https://github.com/meeech/pypi-attestations.git@add-circleci-to-pypi-attestations
pip install id==1.6.0
python -m pypi_attestations sign dist/*
python -m pypi_attestations verify...

https://pypi.org/integrity/sigstore/4.2.0/sigstore-4.2.0.tar.gz/provenance