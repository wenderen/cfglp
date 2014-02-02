
/*********************************************************************************************

                                cfglp : A CFG Language Processor
                                --------------------------------

           About:

           Implemented   by  Tanu  Kanvar (tanu@cse.iitb.ac.in) and Uday
           Khedker    (http://www.cse.iitb.ac.in/~uday)  for the courses
           cs302+cs306: Language  Processors  (theory and  lab)  at  IIT
           Bombay.

           Release  date  Jan  15, 2013.  Copyrights  reserved  by  Uday
           Khedker. This  implemenation  has been made  available purely
           for academic purposes without any warranty of any kind.

           Documentation (functionality, manual, and design) and related
           tools are  available at http://www.cse.iitb.ac.in/~uday/cfglp


***********************************************************************************************/

%scanner ../scanner.h
%scanner-token-function d_scanner.lex()
%filenames parser
%parsefun-source parser.cc

%union 
{
	int integer_value;
	std::string * string_value;
	list<Ast *> * ast_list;
	Ast * ast;
	Symbol_Table * symbol_table;
	Symbol_Table_Entry * symbol_entry;
	Basic_Block * basic_block;
	list<Basic_Block *> * basic_block_list;
	Procedure * procedure;
	Comparison_Op_Enum comparison_op_enum;
};

%token <integer_value> INTEGER_NUMBER
%token <string_value> BASIC_BLOCK
%token <string_value> NAME
%token RETURN INTEGER 
%token IF ELSE GOTO

%token ASSIGN_OP
%left LT LE GT GE
%left NE EQ



%type <symbol_table> declaration_statement_list
%type <symbol_entry> declaration_statement
%type <basic_block_list> basic_block_list
%type <basic_block> basic_block
%type <ast_list> executable_statement_list
%type <ast_list> assignment_statement_list
%type <ast> assignment_statement
%type <ast> variable
%type <ast> constant

%type <comparison_op_enum> comparison_op
%type <ast> comparison_expr
%type <ast> goto_statement
%type <ast> if_statement



%start program

%%

program:
	declaration_statement_list procedure_name
	{
	
		program_object.set_global_table(*$1);
		return_statement_used_flag = false;				// No return statement in the current procedure till now
	
	}
	procedure_body
	{
	
		program_object.set_procedure_map(*current_procedure);

		if ($1)
			$1->global_list_in_proc_map_check(get_line_number());

		delete $1;
	
	}
|
	procedure_name
	{
	
		return_statement_used_flag = false;				// No return statement in the current procedure till now
	
	}
	procedure_body
	{
	
		program_object.set_procedure_map(*current_procedure);
	
	}
;

procedure_name:
	NAME '(' ')'
	{
	
		current_procedure = new Procedure(void_data_type, *$1);
	
	}
;

procedure_body:
	'{' declaration_statement_list
	{
	
		current_procedure->set_local_list(*$2);
		delete $2;
	
	}
	basic_block_list '}'
	{
		#if 0
		if (return_statement_used_flag == false)
		{
			int line = get_line_number();
			report_error("Atleast 1 basic block should have a return statement", line);
		}
		#endif
		//shouldn't it be $3
		current_procedure->set_basic_block_list(*$4);

		delete $4;
	
	}
|
	'{' basic_block_list '}'
	{
		#if 0
		if (return_statement_used_flag == false)
		{
			int line = get_line_number();
			report_error("Atleast 1 basic block should have a return statement", line);
		}
		#endif
		current_procedure->set_basic_block_list(*$2);

		delete $2;
	
	}
;

declaration_statement_list:
	declaration_statement
	{
	
		int line = get_line_number();
		program_object.variable_in_proc_map_check($1->get_variable_name(), line);

		string var_name = $1->get_variable_name();
		if (current_procedure && current_procedure->get_proc_name() == var_name)
		{
			int line = get_line_number();
			report_error("Variable name cannot be same as procedure name", line);
		}

		$$ = new Symbol_Table();
		$$->push_symbol($1);
	
	}
|
	declaration_statement_list declaration_statement
	{
	
		// if declaration is local then no need to check in global list
		// if declaration is global then this list is global list

		int line = get_line_number();
		program_object.variable_in_proc_map_check($2->get_variable_name(), line);

		string var_name = $2->get_variable_name();
		if (current_procedure && current_procedure->get_proc_name() == var_name)
		{
			int line = get_line_number();
			report_error("Variable name cannot be same as procedure name", line);
		}

		if ($1 != NULL)
		{
			if($1->variable_in_symbol_list_check(var_name))
			{
				int line = get_line_number();
				report_error("Variable is declared twice", line);
			}

			$$ = $1;
		}

		else
			$$ = new Symbol_Table();

		$$->push_symbol($2);
	
	}
;

declaration_statement:
	INTEGER NAME ';'
	{
	
		$$ = new Symbol_Table_Entry(*$2, int_data_type);

		delete $2;
	
	}
;

basic_block_list:
	basic_block_list basic_block
	{
	
		if (!$2)
		{
			int line = get_line_number();
			report_error("Basic block doesn't exist", line);
		}

		bb_strictly_increasing_order_check($$, $2->get_bb_number());

		$$ = $1;
		$$->push_back($2);
	
	}
|
	basic_block
	{
	
		if (!$1)
		{
			int line = get_line_number();
			report_error("Basic block doesn't exist", line);
		}

		$$ = new list<Basic_Block *>;
		$$->push_back($1);
	
	}
	
;


basic_block:
	BASIC_BLOCK	':'	executable_statement_list
	{
		
		char num[10];
		string str(*$1);
		for(int i = 4 ; i<str.length(); i++){
			if(str[i] == '>'){
				num[i-4] = '\0';
				break;
			}
			else{
				num[i-4] = str[i];
			}
		}

		if (atoi(num) < 2)
		{
			int line = get_line_number();
			report_error("Illegal basic block lable", line);
		}

		if ($3 != NULL)
			$$ = new Basic_Block(atoi(num), *$3);
		else
		{
			list<Ast *> * ast_list = new list<Ast *>;
			$$ = new Basic_Block(atoi(num), *ast_list);
		}
	
	}
;

executable_statement_list:
	assignment_statement_list
	{
	
		$$ = $1;
	
	}
|
	assignment_statement_list RETURN ';'
	{
	
		Ast * ret = new Return_Ast();

		return_statement_used_flag = true;					// Current procedure has an occurrence of return statement

		if ($1 != NULL)
			$$ = $1;

		else
			$$ = new list<Ast *>;

		$$->push_back(ret);
	
	}
|
	assignment_statement_list goto_statement ';'
	{
	
		//TODO_DONE

		if ($1 != NULL)
			$$ = $1;

		else
			$$ = new list<Ast *>;

		$$->push_back($2);
	
	}
|
	assignment_statement_list if_statement
	{
	
		//TODO_DONE
		if ($1 != NULL)
			$$ = $1;

		else
			$$ = new list<Ast *>;

		$$->push_back($2);
	
	}
;

if_statement:
	IF '(' comparison_expr ')' GOTO BASIC_BLOCK ';' ELSE GOTO BASIC_BLOCK ';'{
	
		//TODO_DONE

		char num1[10];
		char num2[10];
		string str1(*$6);
		string str2(*$10);
		for(int i = 4 ; i<str1.length(); i++){
			if(str1[i] == '>'){
				num1[i-4] = '\0';
				break;
			}
			else{
				num1[i-4] = str1[i];
			}
		}

		for(int i = 4 ; i<str2.length(); i++){
			if(str2[i] == '>'){
				num2[i-4] = '\0';
				break;
			}
			else{
				num2[i-4] = str2[i];
			}
		}

		$$ = new If_Ast($3,atoi(num1),atoi(num2));
		
	
	}
;
	

goto_statement
:	GOTO BASIC_BLOCK {
	//TODO_DONE
	
		char num[10];
		string str(*$2);
		for(int i = 4 ; i<str.length(); i++){
			if(str[i] == '>'){
				num[i-4] = '\0';
				break;
			}
			else{
				num[i-4] = str[i];
			}
		}

		$$ = new Goto_Ast(atoi(num));
	}
;

assignment_statement_list:
	{
	
		$$ = NULL;
	
	}
|
	assignment_statement_list assignment_statement
	{
	
		if ($1 == NULL)
			$$ = new list<Ast *>;

		else
			$$ = $1;

		$$->push_back($2);
	
	}
;

assignment_statement:
	variable ASSIGN_OP variable ';'
	{
	
		$$ = new Assignment_Ast($1, $3);

		int line = get_line_number();
		$$->check_ast(line);
	
	}
|
	variable ASSIGN_OP constant ';'
	{
	
		$$ = new Assignment_Ast($1, $3);

		int line = get_line_number();
		$$->check_ast(line);
	
	}
|
	variable ASSIGN_OP comparison_expr ';'	{
	
		//TODO_DONE
		$$ = new Assignment_Ast($1, $3);

		int line = get_line_number();
		$$->check_ast(line);
	
	}
;

comparison_op
:	NE	{
	//TODO_DONE
		$$ = NE_OP; 
	}
|	GE	{
	//TODO_DONE
		$$ = GE_OP; 
	}
|	LE	{
	//TODO_DONE
		$$ = LE_OP; 
	}
|	EQ	{
	//TODO_DONE
		$$ = EQ_OP; 
	}
|	LT	{
	//TODO_DONE
		$$ = LT_OP; 
	}
|	GT	{
	//TODO_DONE
		$$ = GT_OP; 
	}
;

comparison_expr
:	comparison_expr comparison_op  comparison_expr	{
	
		//TODO_DONE
		$$ = new Comparison_Ast($1,$2,$3);
		int line = get_line_number();
		$$->check_ast(line);
	
	}
|	comparison_expr comparison_op  variable	{
	
		//TODO_DONE
		$$ = new Comparison_Ast($1,$2,$3);
		int line = get_line_number();
		$$->check_ast(line);
	
	}
|	comparison_expr comparison_op constant 	{
	
		//TODO_DONE
		$$ = new Comparison_Ast($1,$2,$3);
		int line = get_line_number();
		$$->check_ast(line);
	
	}
|	variable comparison_op variable 	{
	
		//TODO_DONE
		$$ = new Comparison_Ast($1,$2,$3);
		int line = get_line_number();
		$$->check_ast(line);
	
	}
|	variable comparison_op constant 	{
	
		//TODO_DONE
		$$ = new Comparison_Ast($1,$2,$3);
		int line = get_line_number();
		$$->check_ast(line);
	
	}
|	constant comparison_op constant 	{
	
		//TODO_DONE
		$$ = new Comparison_Ast($1,$2,$3);
		int line = get_line_number();
		$$->check_ast(line);
	
	}
|	constant comparison_op variable 	{
	
		//TODO_DONE
		$$ = new Comparison_Ast($1,$2,$3);
		int line = get_line_number();
		$$->check_ast(line);
	
	}
;

variable:
	NAME
	{
	
		Symbol_Table_Entry var_table_entry;

		if (current_procedure->variable_in_symbol_list_check(*$1))
			 var_table_entry = current_procedure->get_symbol_table_entry(*$1);

		else if (program_object.variable_in_symbol_list_check(*$1))
			var_table_entry = program_object.get_symbol_table_entry(*$1);

		else
		{
			int line = get_line_number();
			report_error("Variable has not been declared", line);
		}

		$$ = new Name_Ast(*$1, var_table_entry);

		delete $1;
	
	}
;

constant:
	INTEGER_NUMBER
	{
	
		$$ = new Number_Ast<int>($1, int_data_type);
	
	}
;
