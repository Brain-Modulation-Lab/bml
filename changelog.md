# Changelog
All notable changes to the BML matlab package will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- bml_write_edf
- bml_rereference
- bml_robust_std
- changelog.md
- automatic documentation with m2html
- bml_annot2spike


### Changed
- bml_annor2raw no longer applies bml_annot_confluence and bml_annot_consolidate to input roi tables
- bml_map now allows different domain and codomain types
- bml_hstack allows concatenating raws with non-matching labels
- bml_load_continuous allows concatenating raws with non-matching labels
- bml_reorder_channels gets new argument cfg.label


## [0.0.0] - 2018-02-20
### Added

Pre-release commits

bfdeb58f9e36439bf8b5eca187c41696b43c6a9b bml_plexon2annot
3005aaab51f67d56797c9ad7b216d40d1f986669 optimized annot_filter
cfd7fd21fa46432129061d3dc2bf407721f123a4 removed use of istrue function
c156a913a8234c70180dcd6ac0d1417949508178 solved bug in bml_defaults
ae4ba3f94a49fcf87432c386c62910fa9de7ae4b incremental upgrades to several functions
7d73113a8b7fd02d70e05aae08374e7c07a8a12e improved bml_read_header usages
94824e0e02843581a377519e56f7d4f35c68b61f removed epoch field in bml_redefinetrial
32ddcc946eeb4370795722ec49231d401fda56ba crosstalk deconvolution
90ef4f508c57d8762bfee0ddfac0b28c97b6dc9d solved bug on coding2annot
70847be6304f956cd9c15ff8b955b98fbcb8d237 corrected ft_redefinetrial
fc5962c64ba3dc8e7b26f9533d9962342006382a bml_reorder_channels and other changes
b02950545be07850abd92b3000dd1e26f43e3ad4 transfer trellis filetype and other improvemetns
db5c7018c541049e9534380af217a8e7cbc86b48 improved bml_load_epoched
0204b4ac4c816624398a05dd5a1a85e04c84ee6e added electrode option to bml_load_continuous and epoched
9fd6d836de41c23015098ecb27efe49ebf753fbd limited working precision to ns
65183dceeccf4aa45fdf5444fd0ca7f83c6e5e3f Multiple improvements and corrections
711575f5d1178499cc87777304801ec2a7d3ade7 Improved NeuroOmega consolidation and bml_coding2annot
10ad405e768cdac8387a2d01ef6b0185d3f8f3fa implemented event based synchronization
283f55692a1507cc5fbacff3e1c80a4d862f5dfc Trialing functions and discontinuous file loading
18c581031be3bea7048a052b893b3407be57671e Solved some issues with sync functions
7311dc3eacb4ed3dda16830e371cb50c25adf726 Preprocessing for coders functions
f4f4127ab0e9f8c3b1ca7e479ef9b284f9d8e997 sync check and consolidate
20951dd47c8c171b627c51eddb7cfaad753c4f07 implemented session synchronization by chunks
40dbb4f4babc9c834c05d8fca82cdedc39ab6635 Preprocess trials for CodingApp script and functions
2845f58103cbfe24090b629ec9fdab4934c5a286 More informative object names in praat
aadd3f4c54acee6c87da67c079286d51b76fb1a5 file synchronization tweeks
8fdb879d7d3f27d44a156f9ab7877616bb8d3efd updated index
9bc755f7d3a5d38e1bdbc7452f9f91b05c1d0d58 implemented file synchronization and time-warping
e408833e80c1be9cd91348ad05d4a86568f1bb7d Updated README.md
501363cb7d63c570ebf9f0e3d78fa990ea3abb4d Added annotation manipulation functions
e57ed999dcbfa89b8a6a10ac329e4ac871e10832 Update README.md
557dd15b52154c79bee3fec7553beef3d9c6f99f Update README.md
bede0852e1fef78c56d37ae7929acee3d646925f Update README.md
fba2a113f5a59f4725169a7df64253b84964b8db Update README.md
81718fbf89f3a5e28e1cbfeeafed1cad20282f06 Edited README.md
c265fc57dba8a2b75306ef7ae4603307a3887e55 Created Contents.m and README.md
c159d11a140d323a014f94526b88bffb1cda752c Copying functions developed in dropbox/Functions/Alan
dc7e09894f5dc04b93b61ffd13b2aa91f383ecbe Initial commit
