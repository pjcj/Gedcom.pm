" Vim syntax file
" Language:     Gedcom
" Maintainer:   Paul Johnson
" Last change:  28th January 1999

" Copyright 1998-1999, Paul Johnson (pjcj@transeda.com)

" This software is free.  It is licensed under the same terms as Vim itself.

" The latest version of this software should be available from my homepage:
" http://www.transeda.com/pjcj

" Version 1.01 - 27th April 1999

" Remove any old syntax stuff hanging around

syntax clear

syntax case match

syntax keyword record ABBR
syntax keyword record ADDR
syntax keyword record ADOP
syntax keyword record ADR1
syntax keyword record ADR2
syntax keyword record AFN
syntax keyword record AGE
syntax keyword record AGNC
syntax keyword record ALIA
syntax keyword record ANCE
syntax keyword record ANCI
syntax keyword record ANUL
syntax keyword record ASSO
syntax keyword record AUTH
syntax keyword record BAPL
syntax keyword record BAPM
syntax keyword record BARM
syntax keyword record BASM
syntax keyword record BIRT
syntax keyword record BLES
syntax keyword record BLOB
syntax keyword record BURI
syntax keyword record CALN
syntax keyword record CAST
syntax keyword record CAUS
syntax keyword record CENS
syntax keyword record CHAN
syntax keyword record CHAR
syntax keyword record CHIL
syntax keyword record CHR
syntax keyword record CHRA
syntax keyword record CITY
syntax keyword record CONC
syntax keyword record CONF
syntax keyword record CONL
syntax keyword record CONT
syntax keyword record COPR
syntax keyword record CORP
syntax keyword record CREM
syntax keyword record CTRY
syntax keyword record DATA
syntax keyword record DATE nextgroup=date
syntax keyword record DEAT
syntax keyword record DESC
syntax keyword record DESI
syntax keyword record DEST
syntax keyword record DIV
syntax keyword record DIVF
syntax keyword record DSCR
syntax keyword record EDUC
syntax keyword record EMIG
syntax keyword record ENDL
syntax keyword record ENGA
syntax keyword record EVEN
syntax keyword record FAM
syntax keyword record FAMC
syntax keyword record FAMF
syntax keyword record FAMS
syntax keyword record FCOM
syntax keyword record FILE
syntax keyword record FORM
syntax keyword record GEDC
syntax keyword record GIVN
syntax keyword record GRAD
syntax keyword record HEAD
syntax keyword record HUSB
syntax keyword record IDNO
syntax keyword record IMMI
syntax keyword record INDI
syntax keyword record LANG
syntax keyword record MARB
syntax keyword record MARC
syntax keyword record MARL
syntax keyword record MARR
syntax keyword record MARS
syntax keyword record MEDI
syntax keyword record NAME nextgroup=name
syntax keyword record NATI
syntax keyword record NATU
syntax keyword record NCHI
syntax keyword record NICK
syntax keyword record NMR
syntax keyword record NOTE
syntax keyword record NPFX
syntax keyword record NSFX
syntax keyword record OBJE
syntax keyword record OCCU
syntax keyword record ORDI
syntax keyword record ORDN
syntax keyword record PAGE
syntax keyword record PEDI
syntax keyword record PHON
syntax keyword record PLAC
syntax keyword record POST
syntax keyword record PROB
syntax keyword record PROP
syntax keyword record PUBL
syntax keyword record QUAY
syntax keyword record REFN
syntax keyword record RELA
syntax keyword record RELI
syntax keyword record REPO
syntax keyword record RESI
syntax keyword record RESN
syntax keyword record RETI
syntax keyword record RFN
syntax keyword record RIN
syntax keyword record ROLE
syntax keyword record SEX
syntax keyword record SLGC
syntax keyword record SLGS
syntax keyword record SOUR
syntax keyword record SPFX
syntax keyword record SSN
syntax keyword record STAE
syntax keyword record STAT
syntax keyword record SUBM
syntax keyword record SUBN
syntax keyword record SURN
syntax keyword record TEMP
syntax keyword record TEXT
syntax keyword record TIME
syntax keyword record TITL
syntax keyword record TRLR
syntax keyword record TYPE
syntax keyword record VERS
syntax keyword record WIFE
syntax keyword record WILL

syntax case ignore

syntax match number "^\s*\d\+"

syntax region id start="@" end="@" oneline contains=ii,in
syntax match ii "\I\+" contained nextgroup=in
syntax match in "\d\+" contained
syntax region name start="" end="$" skipwhite oneline contains=cname,surname contained
syntax match cname "\i\+" contained
syntax match surname "/\(\i\|\s\)*/" contained
syntax match date "\d\{1,2}\s\+\(jan\|feb\|mar\|apr\|may\|jun\|jul\|aug\|sep\|oct\|nov\|dec\)\s\+\d\+"
syntax match date ".*" contained

if !exists("did_ged_syntax_inits")
  let did_ged_syntax_inits = 1
  highlight link record Statement
  highlight link id Comment
  highlight link ii PreProc
  highlight link in Type
  highlight link name PreProc
  highlight link cname Type
  highlight link surname Identifier
  highlight link date Constant
endif
