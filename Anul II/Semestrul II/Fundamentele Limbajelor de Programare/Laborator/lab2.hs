import Data.Char

newtype Parser a = Parser { parse :: String -> [(a,String)] }


item :: Parser Char
item = Parser (\cs -> case cs of
                "" -> []
                (c:cs) -> [(c,cs)])

instance Monad Parser where
    return a = Parser (\cs -> [(a,cs)])
    p >>= f = Parser (\cs -> concat (map (\(a, cs') -> (parse (f a) cs')) (parse p cs)))

instance Applicative Parser where
    pure = return
    mf <*> ma = do
        f <- mf
        va <- ma
        return (f va)    

instance Functor Parser where              
    fmap f ma = pure f <*> ma   
  
zero :: Parser a
zero = Parser (const [])

psum :: Parser a -> Parser a -> Parser a
psum p q = Parser (\cs -> (parse p cs) ++ (parse q cs))

(<|>) :: Parser a -> Parser a -> Parser a
p <|> q = Parser (\cs -> case parse (psum p q) cs of
                                [] -> []
                                (x:xs) -> [x])

dpsum0 :: Parser [a] -> Parser [a]                       
dpsum0 p = p <|> (return [])

sat :: (Char -> Bool) -> Parser Char
sat p = do
            c <- item
            if p c then return c else zero

char :: Char -> Parser Char
char c = sat (c ==)

string :: String -> Parser String
string [] = return []
string (c:cs) = do
                    pc <- char c
                    prest <- string cs
                    return (pc : prest)

many0 :: Parser a -> Parser [a]
many0 p = dpsum0 (many1 p)

many1 :: Parser a -> Parser [a]
many1 p = do 
    a <- p
    aa <- many0 p
    return (a : aa)

spaces :: Parser String
spaces = many0 (sat isSpace)

token :: Parser a -> Parser a
token p = do
            spaces
            a <- p
            spaces
            return a

symbol :: String -> Parser String
symbol symb = token (string symb)

data AExp = Nu Int | Qid String | PlusE AExp AExp | TimesE AExp AExp | DivE AExp AExp
    deriving Show
    
aexp :: Parser AExp
aexp = plusexp <|> mulexp <|> divexp <|> npexp

npexp = parexp <|> qid <|> integer

parexp :: Parser AExp
parexp = do
            symbol "("
            p <- aexp
            symbol ")"
            return p

look :: Parser (Maybe Char)
look = Parser (\cs -> case cs of
      [] -> [(Nothing, [])]
      (c:cs') -> [(Just c, c:cs')]
    )

digit :: Parser Int
digit = do
          d <- sat isDigit
          return (digitToInt d)

integer :: Parser AExp
integer = do
                  spaces
                  s <- look
                  ss <- do
                            if s == (Just '-') then
                                                  do
                                                    item
                                                    return (-1)
                                               else return 1
                  d <- digitToInt <$> sat isDigit
                  if d == 0 
                    then 
                      return (Nu 0)
                    else 
                      do
                        ds <- many0 digit
                        return (Nu (ss*(asInt (d:ds))))
          where asInt ds = sum [d * (10^p) | (d, p) <- zip (reverse ds) [0..] ]

qid :: Parser AExp
qid = do
            char '\''
            a <- many1 (sat isLetter)
            return (Qid a)

plusexp :: Parser AExp
plusexp = do
            p <- npexp
            symbol "+"
            q <- npexp
            return (PlusE p q)

mulexp :: Parser AExp
mulexp = do
            p <- npexp
            symbol "*"
            q <- npexp
            return (TimesE p q)

divexp :: Parser AExp
divexp = do
            p <- npexp
            symbol "/"
            q <- npexp
            return (DivE p q)


data BExp = BE Bool | LE AExp AExp | NotE BExp | AndE BExp BExp
    deriving Show
    
bexp :: Parser BExp
bexp = lexp <|> notexp <|> andexp <|> npexpb

npexpb = parexpb <|> true <|> false

parexpb :: Parser BExp
parexpb = do
            symbol "("
            p <- bexp
            symbol ")"
            return p

true :: Parser BExp
true = do
            symbol "true"
            return (BE True)
-- parse true "  true  " => [(BE True, "")]

false :: Parser BExp
false = do
            symbol "false"
            return (BE False)

lexp :: Parser BExp
lexp = do
            p <- npexp
            symbol "<="
            q <- npexp
            return (LE p q)

notexp :: Parser BExp
notexp =  do
            symbol "not"
            q <- npexpb
            return (NotE q)

andexp :: Parser BExp
andexp = do
            p <- npexpb
            symbol "&&"
            q <- npexpb
            return (AndE p q)
          
data Stmt = AtrE String AExp | Seq Stmt Stmt | IfE BExp Stmt Stmt | WhileE BExp Stmt | Skip
    deriving Show

stmt :: Parser Stmt
stmt = seqp <|> stmtneseq

stmtneseq :: Parser Stmt
stmtneseq = atre <|> ife <|> whileE <|> skip

atre :: Parser Stmt
atre = do
            spaces
            y <- qid
            case y of
                (Qid x) -> do
                            symbol ":="
                            a <- aexp
                            spaces
                            return (AtrE x a)
                _ -> zero
-- parse atre "'abc := 12" => [(AtrE "abc" (Nu 12),"")]

seqp :: Parser Stmt
seqp = do
            x <- stmtneseq
            rest x
      where rest x = (
                     do
                        symbol ";"
                        y <- stmtneseq
                        rest (Seq x y)
                     )
                     <|> return x
-- parse seqp "'abc := 12; 'x := 3" => [(Seq (AtrE "abc" (Nu 12)) (AtrE "x" (Nu 3)),"")]

ife :: Parser Stmt
ife = do
          symbol "if"
          symbol "("
          b <- bexp
          symbol ")"
          symbol "{"
          s1 <- stmt
          symbol "}"
          symbol "else"
          symbol "{"
          s2 <- stmt
          symbol "}"
          return (IfE b s1 s2)
-- parse ife "if (true) {'x := 1} else {'x := 2}" => [(IfE (BE True) (AtrE "x" (Nu 1)) (AtrE "x" (Nu 2)),"")]

whileE :: Parser Stmt
whileE =  do
              symbol "while"
              symbol "("
              b <- bexp
              symbol ")"
              symbol "{"
              s1 <- stmt
              symbol "}"
              return (WhileE b s1)

skip :: Parser Stmt
skip = do
          symbol "skip"
          return Skip

sum_no = unlines ["'n:=100; 's:=0;", "while (not ('n<= 0)) { 's:='s+'n; 'n:= 'n+ (-1)} "]

sum_no_p :: Stmt
sum_no_p = (fst.head) (parse stmt sum_no)
-- sum_no_p =>
-- Seq (Seq (AtrE "n" (Nu 100)) (AtrE "s" (Nu 0))) (WhileE (NotE (LE (Qid "n") (Nu 0))) (Seq (AtrE "s" (PlusE (Qid "s") (Qid "n"))) (AtrE "n" (PlusE (Qid "n") (Nu (-1))))))

inf_cycle = "'n := 0; while (0 <= 0) {'n := 'n +1}"

inf_cycle_p :: Stmt
inf_cycle_p = (fst.head) (parse stmt inf_cycle)
-- inf_cycle_p =>
-- Seq (AtrE "n" (Nu 0)) (WhileE (LE (Nu 0) (Nu 0)) (AtrE "n" (PlusE (Qid "n") (Nu 1))))

recall :: String -> [(String, Int)] -> Int
recall _ [] = 0
recall s ((s1, n1) : t)
    | s == s1   = n1
    | otherwise = recall s t

update :: String -> Int -> [(String, Int)] -> [(String, Int)]
update s n [] = [(s, n)]
update s n ((s1, n1) : t)
    | s == s1   = ((s1, n) : t)
    | otherwise = ((s1, n1) : (update s n t)) 

value :: AExp -> [(String, Int)] -> Int
value (Nu n) _ = n
value (Qid s) l = recall s l
value (PlusE e1 e2) l = (value e1 l) + (value e2 l)
value (TimesE e1 e2) l = (value e1 l) * (value e2 l)
value (DivE e1 e2) l = (value e1 l) `div` (value e2 l)
-- value (PlusE (Nu 2) (Qid "x")) ([("x", 3)]) => 5

valueb :: BExp -> [(String, Int)] -> Bool
valueb (BE b) l = b
valueb (LE e1 e2) l = (value e1 l) <= (value e2 l)
valueb (NotE e) l = not (valueb e l)
valueb (AndE e1 e2) l = (valueb e1 l) && (valueb e2 l)

bssos :: Stmt -> [(String, Int)] -> [(String, Int)]
bssos Skip s = s
bssos (AtrE t e) s = update t (value e s) s
bssos (Seq s1 s2) s = bssos s2 (bssos s1 s)
bssos (IfE be s1 s2) s = if (valueb be s) then (bssos s1 s) else (bssos s2 s)
bssos (WhileE be s1) s = if (valueb be s) then (bssos (WhileE be s1) (bssos s1 s)) else s

sssos1 :: (Stmt, [(String, Int)]) -> (Stmt, [(String, Int)])
sssos1 (AtrE t e, s) = (Skip, update t (value e s) s)
sssos1 (Seq Skip s2, s) = (s2, s)
sssos1 (Seq s1 s2, s) = let (s3, s') = sssos1 (s1, s) in (Seq s3 s2, s')
sssos1 (IfE be s1 s2, s) = if (valueb be s) then (s1, s) else (s2, s)
sssos1 (WhileE be s1, s) = (IfE be (Seq s1 (WhileE be s1)) Skip, s)

sssos_star :: (Stmt, [(String, Int)]) -> [(Stmt, [(String, Int)])]
sssos_star (s1, s) = (s1, s):(sssos_plus (s1, s))

sssos_plus :: (Stmt, [(String, Int)]) -> [(Stmt, [(String, Int)])]
sssos_plus (Skip, s) = []
sssos_plus (s1, s) = (sssos_star . sssos1) (s1, s)

sssos_final_state :: (Stmt, [(String, Int)]) -> [(String, Int)]
sssos_final_state = snd . last . sssos_star

prog = sum_no_p
inits = (prog, [])

test = (sssos_final_state inits) == (bssos prog [])