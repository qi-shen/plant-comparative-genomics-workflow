# Plant comparative genomics workflow
ROOT := $(abspath .)
export PROJECT_ROOT := $(ROOT)

.PHONY: help env orthology phylogeny wgd synteny selection cafe figures all

help:
	@echo "Targets: env orthology phylogeny wgd synteny selection cafe figures all"
	@echo "Or: ./run_all.sh [stage]"

env:
	@test -f .project_env || cp .project_env.example .project_env
	@echo "Edit .project_env and config/species.csv, then: source .project_env"

orthology:
	./run_all.sh orthology

phylogeny:
	./run_all.sh phylogeny

wgd:
	./run_all.sh wgd

synteny:
	./run_all.sh synteny

selection:
	./run_all.sh selection

cafe:
	./run_all.sh cafe

figures:
	./run_all.sh figures

all:
	./run_all.sh all
