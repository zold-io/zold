OPTS=-shell-escape -halt-on-error -interaction=errorstopmode -output-directory=.

wp.pdf: wp.tex
	pdflatex ${OPTS} wp.tex

clean:
	rm -rf wp.log wp.pdf wp.out wp.aux

