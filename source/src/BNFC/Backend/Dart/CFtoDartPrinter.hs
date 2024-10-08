{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TupleSections #-}

module BNFC.Backend.Dart.CFtoDartPrinter (cf2DartPrinter) where

import BNFC.CF
import BNFC.Backend.Dart.Common
import BNFC.Utils       ( (+++) )
import Data.Maybe      ( mapMaybe )
import Data.List ( intercalate, find )
import Data.Either ( isLeft )

cf2DartPrinter :: String -> CF -> String
cf2DartPrinter langName cf = 
  let userTokens = [ n | (n,_) <- tokenPragmas cf ]
  in
    unlines $
      imports ++
      helperFunctions ++
      stringRenderer ++
      (concatMap buildUserToken userTokens) ++
      (concatMap generateRulePrinters $ getAbstractSyntax cf) ++
      (concatMap generateLabelPrinters $ ruleGroupsInternals cf )
  where
    str2DartClassName' = str2DartClassName langName
    getVars' = getVars langName
    cat2DartClassName' = cat2DartClassName langName
    cat2DartType' = cat2DartType langName

    imports :: [String]
    imports = 
      [ "import 'ast.dart' as ast;"
      , "import 'package:fast_immutable_collections/fast_immutable_collections.dart';" ]

    helperFunctions :: [String]
    helperFunctions = 
      [ "sealed class Token {}"
      , ""
      , "class Space extends Token {}"
      , ""
      , "class NewLine extends Token {"
      , "  int indentDifference;"
      , "  NewLine.indent(this.indentDifference);"
      , "  NewLine() : indentDifference = 0;"
      , "  NewLine.nest() : indentDifference = 1;"
      , "  NewLine.unnest() : indentDifference = -1;"
      , "}"
      , ""
      , "class Text extends Token {"
      , "  String text;"
      , "  Text(this.text);"
      , "}" ]

    stringRenderer :: [String]
    stringRenderer = 
      [ "class StringRenderer {"
      , "  // Change this value if you want to change the indentation length"
      , "  static const _indentInSpaces = 2;"
      , ""
      , "  String print(Iterable<String> tokens) => tokens"
      , "      .map((element) => element.trim())"
      , "      .fold(IList<Token>(), _render)"
      , "      .fold(IList<(int, IList<Token>)>(), _split)"
      , "      .map((line) => (line.$1, line.$2.map(_tokenToString).join()))"
      , "      .fold(IList<(int, String)>(), _convertIndentation)"
      , "      .map(_addIndentation)"
      , "      .join('\\n');"
      , ""
      , "  IList<(int, IList<Token>)> _split("
      , "    IList<(int, IList<Token>)> lists,"
      , "    Token token,"
      , "  ) =>"
      , "      switch (token) {"
      , "        NewLine nl => lists.add(("
      , "            nl.indentDifference,"
      , "            IList(),"
      , "          )),"
      , "        _ => lists.isEmpty"
      , "            ? IList(["
      , "                (0, IList([token]))"
      , "              ])"
      , "            : lists.put("
      , "                lists.length - 1,"
      , "                (lists.last.$1, lists.last.$2.add(token)),"
      , "              ),"
      , "      };"
      , ""
      , "  String _tokenToString(Token t) => switch (t) {"
      , "        Text t => t.text,"
      , "        Space _ => ' ',"
      , "        _ => '',"
      , "      };"
      , ""
      , "  IList<(int, String)> _convertIndentation("
      , "    IList<(int, String)> lines,"
      , "    (int, String) line,"
      , "  ) =>"
      , "      lines.add(("
      , "        line.$1 + (lines.lastOrNull?.$1 ?? 0),"
      , "        line.$2,"
      , "      ));"
      , ""
      , "  String _addIndentation((int, String) indentedLine) =>"
      , "      ' ' * (_indentInSpaces * indentedLine.$1) + indentedLine.$2;"
      , ""
      , "  // This function is supposed to be edited"
      , "  // in order to adjust the pretty printer behavior"
      , "  IList<Token> _render(IList<Token> tokens, String token) => switch (token) {"
      , "        '' || ' ' => tokens,"
      , "        '{' => tokens.addAll([Text(token), NewLine.nest()]),"
      , "        '}' => tokens.removeTrailingLines"
      , "            .addAll([NewLine.unnest(), Text(token), NewLine()]),"
      , "        ';' => tokens.removeTrailingSpaces.addAll([Text(token), NewLine()]),"
      , "        ')' || ']' || '>' || ',' => tokens"
      , "            .removeTrailingSpaces.removeTrailingLines"
      , "            .addAll([Text(token), Space()]),"
      , "        '\\$' ||"
      , "        '&' ||"
      , "        '@' ||"
      , "        '!' ||"
      , "        '#' ||"
      , "        '(' ||"
      , "        '[' ||"
      , "        '<' ||"
      , "        '.' =>"
      , "          tokens.removeTrailingLines.add(Text(token)),"
      , "        _ => tokens.addAll([Text(token), Space()])"
      , "      };"
      , "}"
      , ""
      , "extension TokensList on IList<Token> {"
      , "  IList<Token> get removeTrailingLines =>"
      , "      isNotEmpty && last is NewLine ? removeLast().removeTrailingLines : this;"
      , "  IList<Token> get removeTrailingSpaces =>"
      , "      isNotEmpty && last is Space ? removeLast().removeTrailingSpaces : this;"
      , "}"
      , ""
      , "extension PrintableInt on int {"
      , "  String get print => toString();"
      , "}"
      , ""
      , "extension PrintableDouble on double {"
      , "  String get print => toString();"
      , "}"
      , ""
      , "extension PrintableString on String {"
      , "  String get print => this;"
      , "}"
      , ""
      , "extension PrintableIList on IList {"
      , "  String get print => toString();"
      , "}"
      , ""
      , "final _renderer = StringRenderer();"
      , ""
      , "mixin Printable {"
      , "  String get print => \'[not implemented]\';"
      , "}" ]

    buildUserToken :: String -> [String]
    buildUserToken token = 
      let name = censorName langName token
      in [ "Iterable<String> _prettify" ++ name ++ "(ast." ++ name +++ "x) => [x];" ]

    generateLabelPrinters :: (Cat, [Rule]) -> [String]
    generateLabelPrinters (cat, rawRules) = let 
      rules = [ (wpThing $ funRule rule, rhsRule rule) | rule <- rawRules ]
      in if isList cat 
        then let 
          sep = findSep rules
          term = findTerm rules
          vType = cat2DartType' $ normCat cat
          precedence = precCat cat 
          in [
          generateListPrettifier vType precedence sep term,
          generateListPrintFunction vType precedence ]
        else let 
          funs = [ fst rule | rule <- rules ]
          in mapMaybe (generateConcreteMapping cat) rules 
            ++ (concatMap generatePrintFunction $ map str2DartClassName' $ filter representedInAst funs) 
      where
        representedInAst :: String -> Bool
        representedInAst fun = not (
          isNilFun fun ||
          isOneFun fun ||
          isConsFun fun ||
          isConcatFun fun ||
          isCoercion fun )
        findSep :: [(String, [Either Cat String])] -> String
        findSep [] = ""
        findSep ((name, rhs):rest) 
          | isConsFun name = case [ sep | Right sep <- rhs ] of
            (a:_) -> a
            []    -> findSep rest
          | otherwise = findSep rest
        findTerm :: [(String, [Either Cat String])] -> String
        findTerm [] = ""
        findTerm ((name, rhs):rest) 
          | isOneFun name = case [ sep | Right sep <- rhs ] of
            (a:_) -> a
            []    -> findTerm rest
          | otherwise = findTerm rest

    generateRulePrinters :: Data -> [String]
    generateRulePrinters (cat, rules) = 
      let funs = map fst rules
          fun = catToStr cat
      in  
        if isList cat 
          || isNilFun fun 
          || isOneFun fun 
          || isConsFun fun 
          || isConcatFun fun 
          || isCoercion fun 
          || fun `elem` funs 
        then [] -- the category is not presented in the AST
        else 
          let className = cat2DartClassName' cat
          in  (generateRuntimeMapping className $ map fst rules) ++
              (generatePrintFunction className)

    generateRuntimeMapping :: String -> [String] -> [String]
    generateRuntimeMapping name ruleNames = [ 
      "Iterable<String> _prettify" ++ name ++ "(ast." ++ name +++ "a) => switch (a) {" ] ++
      (indent 2 $ map mapRule $ map str2DartClassName' ruleNames) ++ 
      (indent 1 [ "};" ]) 
      where
        mapRule name = "ast." ++ name +++ "a => _prettify" ++ name ++ "(a),"

    generateConcreteMapping :: Cat -> (String, [Either Cat String]) -> Maybe (String)
    generateConcreteMapping cat (label, tokens) 
      | isNilFun label ||
        isOneFun label ||
        isConsFun label ||
        isConcatFun label ||
        isCoercion label = Nothing  -- these are not represented in the AST
      | otherwise = -- a standard rule
        let 
          tokensReversed = foldl (\acc x -> x : acc) [] tokens
          className = str2DartClassName' label
          cats = [ cat | Left cat <- tokensReversed ]
          vars = zip (map precCat cats) (getVars' cats)
        in Just . unlines $ 
          [ "Iterable<String> _prettify" ++ className ++ "(ast." ++ className +++ "a) => [" ] 
          ++ (indent 1 $ generateRuleRHS tokensReversed vars []) 
          ++ ["];"]

    generateListPrettifier :: DartVarType -> Integer -> String -> String -> String 
    generateListPrettifier vType@(n, name) prec separator terminator = 
      "Iterable<String> _prettify" ++ printerListName vType prec ++ "(" ++ 
      printerListType vType +++ "a) => [...a.expand((e" ++ show n ++ 
      ") => [\'" ++ separator ++ "\'," +++ 
      (buildArgument (n - 1, name) prec ("e" ++ show n)) ++
      "],).skip(1)," +++ "\'" ++ terminator ++ "\',];"

    generateRuleRHS :: [Either Cat String] -> [(Integer, DartVar)] -> [String] -> [String]
    generateRuleRHS [] _ lines = lines
    generateRuleRHS (token:rTokens) [] lines = case token of 
      Right terminal -> generateRuleRHS 
          rTokens 
          [] 
          lines ++ (buildTerminal terminal)
      Left _ -> generateRuleRHS rTokens [] lines
    generateRuleRHS 
        (token:rTokens) 
        ((prec, variable@(vType, _)):rVariables) 
        lines = case token of
      Right terminal -> generateRuleRHS 
          rTokens 
          ((prec, variable):rVariables) 
          lines ++ (buildTerminal terminal)
      Left _ -> generateRuleRHS 
          rTokens 
          rVariables
          lines ++ [ buildArgument vType prec ("a." ++ buildVariableName variable) ++ "," ]

    buildTerminal :: String -> [String]
    buildTerminal = (\x -> [x]) 
        . ("'" ++) 
        . (++ "',") 
        . (concatMap (\c -> if c == '\\' then ['\\', '\\'] else [c]))

    buildArgument :: DartVarType -> Integer -> String -> String
    buildArgument (0, name) prec argument = 
      if checkRegistered name 
        then argument ++ ".print"
        else "..._prettify" ++ (str2DartClassName' name) ++ "(" ++ argument ++ ")"
    buildArgument vType@(n, name) prec argument = "..._prettify" 
        ++ printerListName vType prec ++ "(" ++ argument ++ ")"

    generatePrintFunction :: String -> [String]
    generatePrintFunction name = [ 
      "String print" ++ name ++ "(ast." ++ name +++ "x)" +++ "=> _renderer.print(_prettify" ++ name ++ "(x));" ]

    generateListPrintFunction :: DartVarType -> Integer -> String
    generateListPrintFunction dvt prec = 
      "String print" ++ printerListName dvt prec ++ "(" ++ printerListType dvt +++ "x)" +++ "=> _renderer.print(_prettify" ++ printerListName dvt prec ++ "(x));" 

    printerListName :: DartVarType -> Integer -> String
    printerListName (0, name) prec = name ++ if prec <= 0 then "" else (show prec)
    printerListName (n, name) prec = "List" ++ (printerListName (n - 1, name) prec)

    printerListType :: DartVarType -> String
    printerListType (0, name) 
      | checkBuiltIn name = name
      | otherwise = "ast." ++ name
    printerListType (n, name) = "Iterable<" ++ printerListType (n - 1, name) ++ ">"