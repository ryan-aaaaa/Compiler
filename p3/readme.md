# Progject 3: Code Generation (Java Bytecode)
B11115030 陳毅恩

## build & compile
```
make example
```
```
make run
```


## clean 
```
make clean
```


## 問題
1. foreach 沒了
2. field 只能在最前面，是語言的限制嗎?
3. foreach 


## 方法
每個 stmt 都會被推入棧，當匹配到 stmt 的文法時，將棧頂的兩個 stmt 串接，再推回棧，對於 if-else, loop, function, 當匹配成功時，stmt 都會剛好在棧頂，在根據這三種語法將 stmt 內容包裝起來


## parser 改動
1. 新增 CodeGenerator 物件，用來產生 jasm
2. void function 可以不宣告資料型態
3. 


## parser 功能
### 基本功能
- [x] scalar data types: bool, float, int, string
- [x] structured data type: array
- [x] declaration: constant, variable, function, array
- [x] statement: block, simple, expression, function invocation, loop, return
- [x] main function checking
- [x] dump symbol table after exiting each scope
