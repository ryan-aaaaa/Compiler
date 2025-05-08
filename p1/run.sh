# input files
files=(
    code1.sd 
    code2.sd 
    code3.sd 
    code4.sd 
    code5.sd
)

flex b11115030.l
g++ lex.yy.c -o b11115030 -ll
for file in "${files[@]}"; do
    ./b11115030 < "$file"
done


# flex b11115030.l
# g++ lex.yy.c -o b11115030 -ll
# ./b11115030 < code1.sd 
# ./b11115030 < code2.sd 
# ./b11115030 < code3.sd 
# ./b11115030 < code4.sd 
# ./b11115030 < code5.sd 



