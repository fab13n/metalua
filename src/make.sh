#! /bin/sh

# --- BEGINNING OF USER-EDITABLE PART ---

# Metalua sources
BASE=${PWD}

if [ -z "${BUILD_BIN}" ]; then
  BUILD_BIN=../../bin
fi

if [ -z "${BUILD_LIB}" ]; then
  BUILD_LIB=../../resources
fi

if [ -z "${BC_EXT}" ]; then
  BC_EXT=lbc
fi

# Make paths absolute (in case they were relative)
BUILD_BIN=$(cd ${BUILD_BIN}; pwd)
BUILD_LIB=$(cd ${BUILD_LIB}; pwd)

# Where to find Lua executables.
# On many Debian-based systems, those can be installed with "sudo apt-get install lua5.1"
LUA=$(which lua)
LUAC=$(which luac)

# --- END OF USER-EDITABLE PART ---


echo '*** Lua paths setup ***'

export LUA_PATH="?.${BC_EXT};?.lua;${BUILD_LIB}/?.${BC_EXT};${BUILD_LIB}/?.lua"
export LUA_MPATH="?.mlua;${BUILD_LIB}/?.mlua"

echo '*** Create the distribution directories, populate them with lib sources ***'

mkdir -p ${BUILD_BIN}
mkdir -p ${BUILD_LIB}
cp -Rp lib/* ${BUILD_LIB}/

echo '*** Generate a callable metalua shell script ***'

cat > ${BUILD_BIN}/metalua <<EOF
#!/bin/sh
export LUA_PATH='?.${BC_EXT};?.lua;${BUILD_LIB}/?.${BC_EXT};${BUILD_LIB}/?.lua'
export LUA_MPATH='?.mlua;${BUILD_LIB}/?.mlua'
${LUA} ${BUILD_LIB}/metalua.${BC_EXT} \$*
EOF
chmod a+x ${BUILD_BIN}/metalua

echo '*** Compiling the parts of the compiler written in plain Lua ***'

cd compiler
${LUAC} -o ${BUILD_LIB}/metalua/bytecode.${BC_EXT} lopcodes.lua lcode.lua ldump.lua compile.lua
${LUAC} -o ${BUILD_LIB}/metalua/mlp.${BC_EXT} lexer.lua gg.lua mlp_lexer.lua mlp_misc.lua mlp_table.lua mlp_meta.lua mlp_expr.lua mlp_stat.lua mlp_ext.lua
cd ..

echo '*** Bootstrap the parts of the compiler written in metalua ***'

${LUA} ${BASE}/build-utils/bootstrap.lua ${BASE}/compiler/mlc.mlua output=${BUILD_LIB}/metalua/mlc.${BC_EXT}
${LUA} ${BASE}/build-utils/bootstrap.lua ${BASE}/compiler/metalua.mlua output=${BUILD_LIB}/metalua.${BC_EXT}

echo '*** Finish the bootstrap: recompile the metalua parts of the compiler with itself ***'

${BUILD_BIN}/metalua -vb -f compiler/mlc.mlua     -o ${BUILD_LIB}/metalua/mlc.${BC_EXT}
${BUILD_BIN}/metalua -vb -f compiler/metalua.mlua -o ${BUILD_LIB}/metalua.${BC_EXT}

echo '*** Precompile lua & metalua libraries ***'
for SRC in $(find ${BUILD_LIB} -name '*.mlua'); do
    DST=$(dirname $SRC)/$(basename $SRC .mlua).${BC_EXT}
    if [ $DST -nt $SRC ]; then
        echo "  [OK]\t+ $DST already up-to-date"
    else
        echo "  -do-\t- $DST generated from $SRC"
        ${BUILD_BIN}/metalua $SRC -o $DST
    fi
done

for SRC in $(find ${BUILD_LIB} -name '*.lua'); do
    DST=$(dirname $SRC)/$(basename $SRC .lua).${BC_EXT}
    if [ $DST -nt $SRC ]; then
        echo "  [OK]\t+ $DST already up-to-date"
    else
        echo "  -do-\t- $DST generated from $SRC"
        luac -o $DST $SRC
    fi
done

echo '*** Generate metalua shell script ***'

cat > ${BUILD_BIN}/metalua <<EOF
#!/bin/sh
METALUA_LIB=${BUILD_LIB}
export LUA_PATH="?.${BC_EXT};?.lua;\\\${METALUA_LIB}/?.${BC_EXT};\\\${METALUA_LIB}/?.lua"
export LUA_MPATH="?.mlua;\\\${METALUA_LIB}/?.mlua"
exec ${LUA} \\\${METALUA_LIB}/metalua.${BC_EXT} "\\\$@"
EOF

chmod a+x ${BUILD_BIN}/metalua

echo
echo "Build completed in ${BUILD_LIB}, metalua executable in ${BUILD_BIN}"
echo
