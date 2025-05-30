#include "SymbolTable.hpp"
#include "AST.hpp"
#include <iostream>
#include <string>
#include <vector>
#include <unordered_map>




SymbolTable::SymbolTable(bool isGlobal){
    this->parent = nullptr;
    this->counter = 0;
    this->isGlobal = isGlobal;
}

SymbolTable::~SymbolTable(){
    // free memory
    for(SymbolTable* child : children){
        delete child;
    }
}



AstNode* SymbolTable::lookup(string s) {
    auto it = table.find(s);
    if (it != table.end()) return it->second;

    SymbolTable* ptr = this->parent;
    while (ptr) {
        auto it2 = ptr->table.find(s);
        if (it2 != ptr->table.end()) return it2->second;
        ptr = ptr->parent;
    }

    return nullptr;
}


bool SymbolTable::insert(AstNode* entry){
    string name = entry->name;
    if(table.find(name) != table.end()) return false; // already exist
    if(!(entry->isArray || entry->isConst || entry->isFunc || entry->isGlobal)){
        entry->number = counter;
        counter++;
    }
    table[name] = entry;
    identifiers.push_back(name);
    return true;
}

#include <iomanip>
void SymbolTable::dump(){
    cout << endl << string(84, '=') << endl;
    cout << left << setw(30) << "Symbol Name"
         << setw(15) << "Data Type"
         << setw(10) << "isConst"
         << setw(10) << "isArray"
         << setw(10) << "isFunc"
         << setw(10) << "isGlobal"
         << setw(10) << "number"
         << endl;
    cout << string(84, '-') << endl;

    for(string& id : identifiers){
        AstNode* info = table[id];
        cout << left << setw(30) << id
                << setw(15) << getTypeStr(info->dataType)
                << setw(10) << info->isConst
                << setw(10) << info->isArray
                << setw(10) << info->isFunc
                << setw(10) << info->isGlobal
                << setw(10) << info->number
                << endl;        
    }
    cout << string(84, '=') << endl << endl;;
}


// // dump symbol table and all its child's symbol table recursively
// void SymbolTable::recursiveDump(int depth){
//     std::string indent(depth, '\t');              
//     for (const auto& [name, _] : table) {
//         std::cout << indent << name << '\n';
//     }
//     cout << endl; 
    
//     for (SymbolTable* child : children) {
//         if (child) child->recursiveDump(depth + 1);
//     }
// }

