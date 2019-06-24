/*
 * Copyright (C) BedRock Systems Inc. 2019 Gregory Malecha
 *
 * SPDX-License-Identifier:AGPL-3.0-or-later
 */
#include "ClangPrinter.hpp"
#include "CoqPrinter.hpp"
#include "Formatter.hpp"
#include <clang/AST/ASTContext.h>
#include <clang/AST/Expr.h>
#include <clang/AST/Mangle.h>
#include <clang/AST/Stmt.h>

#include <cstdio>
using namespace clang;

ClangPrinter::ClangPrinter(clang::ASTContext *context)
        : context_(context), engine_(IntrusiveRefCntPtr<DiagnosticIDs>(),
                                     IntrusiveRefCntPtr<DiagnosticOptions>())
{
  mangleContext_ = ItaniumMangleContext::create(*context, engine_);
}

unsigned ClangPrinter::getTypeSize(const BuiltinType* t) const {
  return this->context_->getTypeSize(t);
}

void ClangPrinter::printGlobalName(const NamedDecl *decl, CoqPrinter &print, bool raw)
{
  if (!raw) { print.output() << "\""; }
  if (auto fd = dyn_cast<FunctionDecl>(decl)) {
    if (fd->getLanguageLinkage() == LanguageLinkage::CLanguageLinkage) {
      print.output() << fd->getName();
    } else {
      mangleContext_->mangleCXXName(decl, print.output().nobreak());
    }
  } else {
    mangleContext_->mangleCXXName(decl, print.output().nobreak());
  }
  if (!raw) { print.output() << "\""; }
}

void ClangPrinter::printName(const NamedDecl *decl, CoqPrinter &print)
{
  if (decl->getDeclContext()->isFunctionOrMethod()) {
    print.ctor("Lname", false);
    print.output() << fmt::nbsp << "\"" << decl->getNameAsString() << "\"";
  } else {
    print.ctor("Gname", false);
    printGlobalName(decl, print);
  }
  print.output() << fmt::rparen;
}

void ClangPrinter::printValCat(const Expr *d, CoqPrinter &print)
{
  auto Class = d->Classify(*this->context_);
  if (Class.isLValue()) {
    print.output() << "Lvalue";
  } else if (Class.isXValue()) {
    print.output() << "Xvalue";
  } else if (Class.isRValue()) {
    assert(!d->isLValue());
    assert(d->isRValue());
    print.output() << "Rvalue";
  } else {
    assert(false);
    //fatal("unknown value category");
  }
}

void ClangPrinter::printExprAndValCat(const Expr *d, CoqPrinter &print)
{
  auto depth = print.output().get_depth();
  print.output() << fmt::lparen;
  printValCat(d, print);
  print.output() << "," << fmt::nbsp;
  printExpr(d, print);
  print.output() << fmt::rparen;
  assert(depth == print.output().get_depth());
}
