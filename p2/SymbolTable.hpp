#ifndef SYMBOLTABLE_HPP
#define SYMBOLTABLE_HPP

#include <string>
#include <vector>
#include <unordered_map>
#include "AST.hpp"   // for AstNode

using namespace std;



class SymbolTable{
public:
    unordered_map<string, AstNode> table;
    SymbolTable* parent;
    vector<SymbolTable*> children;
    vector<string> identifiers; // for insert order

    SymbolTable();
    ~SymbolTable();
    AstNode* lookup(string s);
    bool insert(AstNode entry);
    void dump();
    // void recursiveDump(int depth);
};




#endif // SYMBOLTABLE_HPP