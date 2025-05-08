#include "SymbolTable.hpp"
#include "AST.hpp"
#include <iostream>
#include <string>
#include <vector>
#include <unordered_map>




SymbolTable::SymbolTable(){
    this->parent = nullptr;
}


AstNode* SymbolTable::lookup(string s) {
    auto it = table.find(s);
    if (it != table.end()) return &it->second;

    SymbolTable* ptr = this->parent;
    while (ptr) {
        auto it2 = ptr->table.find(s);
        if (it2 != ptr->table.end()) return &it2->second;
        ptr = ptr->parent;
    }

    return nullptr;
}


bool SymbolTable::insert(AstNode entry){
    string name = entry.name;
    if(table.find(name) != table.end()) return false; // already exist
    table[name] = entry;
    return true;
}
#include <iomanip>
void SymbolTable::dump(){
    cout << endl << "==================================================================================" << endl;
    cout << left << setw(30) << "Symbol Name"
         << setw(15) << "Data Type"
         << setw(10) << "isConst"
         << setw(10) << "isArray"
         << setw(10) << "isFunc"
         << endl;

    cout << "----------------------------------------------------------------------------------" << endl;
    for(auto& [name, info] : table){
        cout << left << setw(30) << name
             << setw(15) << getTypeStr(info.dataType)
             << setw(10) << info.isConst
             << setw(10) << info.isArray
             << setw(10) << info.isFunc
             << endl;        
    }
    cout << "==================================================================================" << endl << endl;
}


// dump symbol table and all its child's symbol table recursively
void SymbolTable::recursiveDump(int depth){
    std::string indent(depth, '\t');              
    for (const auto& [name, _] : table) {
        std::cout << indent << name << '\n';
    }
    cout << endl; 
    
    for (SymbolTable* child : children) {
        if (child) child->recursiveDump(depth + 1);
    }
}

