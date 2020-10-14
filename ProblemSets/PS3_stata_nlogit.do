clear all
version 14.1
set more off
capture log close

log using PS3_stata_nlogit.log, replace

webuse nlsw88, clear
drop if mi(occupation)
recode occupation (8 9 10 11 12 = 7)
gen white = race==1
mlogit occupation age white collgrad, base(13)

gen lnwage = log(wage)
gen lnhrs  = log(hours)
foreach j in 1 2 3 4 5 6 7 13 {
    qui reg lnwage c.age##c.age b0.white b0.collgrad b0.c_city if occupation==`j'
    predict elnwage`j', xb
    * qui reg lnhrs  c.age##c.age b0.white b0.collgrad b0.c_city if occupation==`j'
    * predict elnhrs`j', xb
    * qui sum union if occupation==`j'
    * qui gen pctunion`j' = `r(mean)'
}

keep idcode occupation age white collgrad elnwage*
preserve
    ren elnwage13 elnwage8
    recode occupation (13 = 8)
    outsheet using nlsw88w.csv, comma replace nol
restore

reshape long elnwage, i(idcode occupation age white collgrad) j(occ)

gen chosen = occ==occupation
lab val occ occlbl
drop occupation
drop if occ>7 & occ<13

* multinomial logit (with Z's)
asclogit chosen elnwage , case(idcode) alternatives(occ) casevars(age white collgrad) noconst base(13)

* nested logit (with Z's)
nlogitgen type = occ(white: Professional/technical | Managers/admin | Sales, blue: Clerical/unskilled | Craftsmen | Operatives | Transport, other: Other)
nlogittree occ type, choice(chosen) case(idcode)
constraint 1 [other_tau]_cons              = 1
constraint 2 [Professional_technical]_cons = 0
constraint 3 [Clerical_unskilled]_cons     = 0
constraint 4 [Clerical_unskilled]white     = 0
nlogit   chosen elnwage || type: age white collgrad,   base(blue) || occ:                   , noconst case(idcode) base(13) constraints(1)
nlogit   chosen elnwage || type:                   ,   base(blue) || occ: age white collgrad, noconst case(idcode) base(13) constraints(1)
nlogit   chosen elnwage || type:           collgrad,   base(blue) || occ: age white         ,         case(idcode) base(13) constraints(1/4) iterate(50)

log close

