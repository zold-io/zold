OPTS=-shell-escape -halt-on-error -interaction=errorstopmode -output-directory=.

wp.pdf: wp.tex
	pdflatex ${OPTS} wp.tex > /dev/null
	biber wp > /dev/null
	pdflatex ${OPTS} wp.tex > /dev/null
	grep 'LaTeX Warning' wp.log ; if [ $$? -eq 0 ]; then cat wp.log; exit -1; fi
	grep 'Overfull ' wp.log ; if [ $$? -eq 0 ]; then cat wp.log; exit -1; fi
	grep 'Underfull ' wp.log ; if [ $$? -eq 0 ]; then cat wp.log; exit -1; fi

clean:
	rm -rf wp.log wp.pdf wp.out wp.aux

