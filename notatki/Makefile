# Notatki do kursu: make -> kurs.pdf
#   make          buduje kurs.pdf (pdflatex, kilka przebiegów przez latexmk)
#   make clean    usuwa pliki pośrednie
#   make watch    przebudowuje po każdej zmianie
LATEXMK := latexmk -pdf -interaction=nonstopmode -halt-on-error -file-line-error

kurs.pdf: kurs.tex kurs.sty $(wildcard rozdzialy/*.tex)
	$(LATEXMK) kurs.tex

watch:
	$(LATEXMK) -pvc kurs.tex

clean:
	latexmk -C kurs.tex

.PHONY: watch clean
