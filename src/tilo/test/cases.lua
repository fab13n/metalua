return {
    typeof = {
        num = { [[return 123]], [[number]] },
        loc_const = { [[local x #const tx = 123; return x]], [[number]] },
        loc_var = { [[local x #var tx = 123; return x]], [[number]] },
        loc_curr = { [[local x #currently tx = 123; return x]], [[number]] },
        loc_guess = { [[local x = 123; return x]], [[number]] },
    }, 
    eq = {
        te = {
            tid = { "foo", "foo", true },
            neq_tid = { "foo", "bar", false },
            tab1 = { "[const nil]", "[const nil]", true},
            tab2 = { "[const nil]", "[const nil, 'k'=const nil]", true},
            tab3 = { "[const nil; 'k'=const nil]", "[const nil]", true},
            neq_tab1 = { "[const nil]", "[const number]", false},
            neq_tab2 = { "[const nil; 'k'=var nil]", "[const nil]", false},
        },
        tebar = {
        },
        tf = {
        },
        ts = {
        }
    },
    min = {
        te = {
        },
        tebar = {
        },
        tf = {
        },
        ts = {
        }
    },
    max = {
        te = {
        },
        tebar = {
        },
        tf = {
        },
        ts = {
        }
    },
}
