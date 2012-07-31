
all: zpuino.pdf

zpuino.pdf: zpuino.tex releasenotes.tex
	pdflatex -halt-on-error -interaction=nonstopmode zpuino.tex 
	pdflatex -halt-on-error -interaction=nonstopmode zpuino.tex # 2nd run
