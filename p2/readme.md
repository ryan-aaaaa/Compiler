# Progject 2: Syntax Analysis (Parser)
B11115030 陳毅恩

## build & compile
```
make
```

## run
```
./parser example.sd
```

## clean 
```
make clean
```



## scanner 改了什麼
1. 引入 `y.tab.hpp`，使用 token 的 define
2. 根據讀到的 token 回傳相對應的 token 
3. token 不輸出
4. 移除 main() 到 parser 處理
5. 移除 symboltable 到 parser 處理
6. 加入 yywarp()
7. 刪除 sign 規則，並在 parser 使用文法處理 


## parser 功能
### 基本功能
- [x] scalar data types: bool, float, int, string
- [x] structured data type: array
- [x] declaration: constant, variable, function, array
- [x] statement: block, simple, expression, function invocation, loop, return
- [x] main function checking
- [x] dump symbol table after exiting each scope

### 額外功能
- [x] UPLUS 可以用
- [x] constant 可以像 variable 用 identifier list 宣告
- [x] variable 宣告可以接受 expr 包含之前宣告的 variable 
- [x] array 可以和 variable 一起宣告
- [x] 可以接受 `return ;`
- [x] if/if-else 支援 simple/block 以外的 stmt
- [x] while/for/foreach 支援 simple/block 以外的 stmt
- [x] array 可以被一個相同維度且相同大小的 array 賦值
- [x] array slicing 可以, 也可以被一個相同維度且相同大小的 array 賦值



