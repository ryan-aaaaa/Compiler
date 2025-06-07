# Progject 3: Code Generation (Java Bytecode)
B11115030 陳毅恩

## build & compile
```
make example
```
## generate java byte code & run 
```
make run
```
## clean 
```
make clean
```

## parser 改動
1. 新增 CodeGenerator 物件，用來產生 jasm
2. void function 可以不宣告資料型態
3. ast node 新增 code gen 需要的 attribute



## method
使用 stack 存放所有的 jasm，當所有程式碼被解析，stack 只會剩餘 generated jasm 一個元素 
- expr: expr 會被建成 expr tree，在使用 dfs 生成對應的 jasm
- stmt: 當解析到 stmt，生成對應的 jasm 並堆入 stack
- stmt_list: 串接 stack top 的兩個 stmt 再推回 stack
- declaration: 當解析到 stmt，生成對應的 jasm 並堆入 stack
- program: 當解析到 program，產生 java class 做包裝



## functionality
- [x] initialization
- [x] parsing declarations for constants and variables
- [x] code generation for expressions and statements
- [x] code generation for conditional statements and loops
- [x] code generation for procedure calls
