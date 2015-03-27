#!/bin/bash
# Make slides for lectures.
#
# ../make_slides.sh slides_ch2
set -x

slidesname=$1
# Strip off slides_ in $slidesname to get the nickname
nickname=`echo $slidesname | sed 's/slides_//'`
dofile=$slidesname.do.txt
if [ ! -f $dofile ]; then
  echo "No such file: $dofile"
  exit 1
fi

# Safe execution of doconce commands - with abortion if they don't succeed
function system {
  "$@"
  if [ $? -ne 0 ]; then
    echo "make.sh: unsuccessful command $@"
    echo "abort!"
    exit 1
  fi
}

rm -rf tmp*

# Spellcheck files first (this is done in subdirectories so updated
# dictionaries are located there!)
dir=`/bin/ls -d lec-*`  # assume only one lec_* dir...
cd $dir
rm -rf tmp*
system doconce spellcheck -d ../.dict4spell.txt *.do.txt
cd ..

# It is wise to first compile a plain LaTeX PDF version of
# the sides/study gude since that will reveal potential syntax errors.
# (HTML gives far less errors and warnings than LaTeX).
rm -f *.aux
system preprocess -DFORMAT=pdflatex ../newcommands.p.tex > newcommands_keep.tex

system doconce format pdflatex $slidesname --latex_admon=paragraph "--latex_code_style=default:lst-yellow2@sys:vrb[frame=lines,label=\\fbox{{\tiny Terminal}},framesep=2.5mm,framerule=0.7pt]"
doconce replace 'section{' 'section*{' ${slidesname}.tex

system pdflatex $slidesname
system pdflatex $slidesname
cp -f $slidesname.pdf ${slidesname}-plain.pdf

# HTML versions
system preprocess -DFORMAT=html ../newcommands.p.tex > newcommands_keep.tex
opt="-DWITH_TOC"

# reveal.js HTML5 slides
html=${slidesname}-reveal
system doconce format html $slidesname --pygments_html_style=native --keep_pygments_html_bg --html_output=$html $opt
system doconce slides_html ${html}.html reveal --html_slide_theme=darkgray

html=${slidesname}-reveal-beige
system doconce format html $slidesname --pygments_html_style=perldoc --keep_pygments_html_bg --html_output=$html $opt
system doconce slides_html ${html}.html reveal --html_slide_theme=beige

# deck.js HTML5 slides
html=${slidesname}-deck
system doconce format html $slidesname --pygments_html_style=perldoc --keep_pygments_html_bg --html_output=$html $opt
system doconce slides_html ${html}.html deck --html_slide_theme=sandstone.default

# Plain HTML with everything in one file (fine for browsing and turning up the font in the browser)
html=${slidesname}-1
system doconce format html $slidesname --html_style=bloodish --html_output=$html  $opt
doconce replace "<li>" "<p><li>" ${html}.html  # add space around bullets
doconce split_html ${html}.html --method=space8

# HTML with solarized style in one big file
html=${slidesname}-solarized
system doconce format html $slidesname --html_style=solarized3 --html_output=$html --pygments_html_style=perldoc --pygments_html_linenos $opt
doconce replace "<li>" "<p><li>" ${html}.html  # add space around bullets
doconce split_html ${html}.html --method=space8
# Can split plain html slides too into one file per slide...

# Markdown Remark style (for web browser viewing)
doconce format pandoc $slidesname --github_md $opt
doconce slides_markdown $slidesname remark --slide_theme=light
cp $slidesname.html ${slidesname}-remark.html

# LaTeX Beamer slides with plain pygments style for code
rm -f *.aux
preprocess -DFORMAT=pdflatex ../newcommands_keep.p.tex > newcommands_keep.tex

system doconce format pdflatex $slidesname --latex_title_layout=beamer --latex_table_format=footnotesize --latex_admon_title_no_period --latex_code_style=pyg
# Note: no TOC for beamer, that is built in
theme=red_shadow
system doconce slides_beamer $slidesname --beamer_slide_theme=$theme

system pdflatex -shell-escape $slidesname
pdflatex -shell-escape $slidesname
pdflatex -shell-escape $slidesname
cp ${slidesname}.pdf ${slidesname}-beamer.pdf
rm -f ${slidesname}.pdf
cp ${slidesname}.tex ${slidesname}-beamer.tex  # sometimes handy to check

# Handouts
system doconce format pdflatex $slidesname --latex_title_layout=beamer --latex_table_format=footnotesize --latex_admon_title_no_period --latex_code_style=pyg
system doconce slides_beamer $slidesname --beamer_slide_theme=red_shadow --handout

system pdflatex -shell-escape $slidesname
pdflatex -shell-escape $slidesname
pdflatex -shell-escape $slidesname
pdfnup --nup 2x3 --frame true --delta "1cm 1cm" --scale 0.9 --outfile ${slidesname}-beamer-handouts2x3.pdf ${slidesname}.pdf
rm -f ${slidesname}.pdf

# Publish
dest=/some/repo/some/where
dest=../../../pub
if [ ! -d $dest ]; then
exit 0  # drop publishig
fi
dest=$dest/$nickname
if [ ! -d $dest ]; then
  echo "No publish dir $dest exists!"
  exit 1
fi
#cp -r ${slidesname}-*.html ._${slidesname}-*.html $dest/html
cp -r ${slidesname}-*.html $dest/html

if [ -d fig-$nickname ]; then
if [ ! -d $dest/$fig-$nickname ]; then
cp -r fig-$nickname $dest/html
else
cp -r fig-$nickname/* $dest/html/fig-$nickname/
fi
fi
cd $dest
git add html