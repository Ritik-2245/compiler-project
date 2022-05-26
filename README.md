## commands to run on windows
 bison -d rkv.y        
 flex rkv.l   
 gcc -o rkv lex.yy.c rkv.tab.c  

## execute the programs 
./rkv.exe file_name   
or  
./rkv.exe program
      