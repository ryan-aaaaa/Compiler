## scanner 做了什麼改變
1. 引入 "y.tab.hpp"
2. 把抓到的 token 根據他的型態，回傳相對應的型態 
3. 移除 main 和 symboltable 到 parser 處理
4. yywrap
5. 刪除 sign，parser 加入 uplus, uminus


## parser 做了什麼
### 基本功能
- [x] scalar data types: bool, float, int, string
- [x] structured data type: array
- [x] declaration: constant, variable, function, array
- [x] statement: block, simple, expression, function invocation, loop, return
- [x] main function checking
- [x] dump symbol table after exiting scope


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



- [ ] makefile 裡面包含 run 的腳本



# What to Submit
* revised version of your lex scanner
* a file describing what changes you have to make to your scanner your yacc parser
*  Note: comments must be added to describe statements in your program
* Makefile
* test programs