
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
	pair<Data_Type, string> * decl;
	list<Ast *> * ast_list;
	Ast * ast;
	Symbol_Table * symbol_table;
	Symbol_Table_Entry * symbol_entry;
	Basic_Block * basic_block;
	list<Basic_Block *> * basic_block_list;
	Comparison_Op_Enum comparison_op_enum;
	Data_Type data_type;
	Procedure * procedure;
};

%token <integer_value> INTEGER_NUMBER BBNUM
%token <string_value> NAME
%token RETURN INTEGER
%token IF ELSE GOTO
%token ASSIGN_OP NE EQ LT LE GT GE

%type <symbol_table> optional_variable_declaration_list
%type <symbol_table> variable_declaration_list
%type <symbol_entry> variable_declaration
%type <decl> declaration
%type <basic_block_list> basic_block_list
%type <basic_block> basic_block
%type <ast_list> executable_statement_list
%type <ast_list> assignment_statement_list
%type <ast> assignment_statement
%type <ast> var_const
%type <ast> var_const_plain
%type <ast> variable
%type <ast> constant

%type <comparison_op_enum> equality_op
%type <comparison_op_enum> comparison_op
%type <ast> comparison_expr
%type <ast> h_comparison_expr
%type <ast> all_expr
%type <ast> goto_statement
%type <ast> if_statement

%start program

%%

program:
	optional_declaration_list procedure_definition
	{
	if (NOT_ONLY_PARSE)
	{
		CHECK_INVARIANT((current_procedure != NULL), "Current procedure cannot be null");

		program_object.set_procedure_map(current_procedure, get_line_number());
		program_object.global_list_in_proc_map_check();
	}
	}
;

optional_declaration_list:
	{
	if (NOT_ONLY_PARSE)
	{
		Symbol_Table * global_table = new Symbol_Table();
		program_object.set_global_table(*global_table);
	}
	}
|
	variable_declaration_list
	{
	if (NOT_ONLY_PARSE)
	{
		Symbol_Table * global_table = $1;

		CHECK_INVARIANT((global_table != NULL), "Global declarations cannot be null");

		program_object.set_global_table(*global_table);
	}
	}
;

procedure_definition:
	NAME '(' ')'
	{
	if (NOT_ONLY_PARSE)
	{
		CHECK_INVARIANT(($1 != NULL), "Procedure name cannot be null");

		string proc_name = *$1;

		current_procedure = new Procedure(void_data_type, proc_name, get_line_number());
	}
	}

	'{' optional_variable_declaration_list
	{
	if (NOT_ONLY_PARSE)
	{

		CHECK_INVARIANT((current_procedure != NULL), "Current procedure cannot be null");

		Symbol_Table * local_table = $6;

		if (local_table == NULL)
			local_table = new Symbol_Table();

		current_procedure->set_local_list(*local_table);
	}
	}

	basic_block_list '}'
	{
	if (NOT_ONLY_PARSE)
	{
		list<Basic_Block *> * bb_list = $8;

		CHECK_INVARIANT((current_procedure != NULL), "Current procedure cannot be null");
		CHECK_INVARIANT((bb_list != NULL), "Basic block list cannot be null");

		current_procedure->set_basic_block_list(*bb_list);
	}
	}
;

optional_variable_declaration_list:
	{
	if (NOT_ONLY_PARSE)
	{
		$$ = NULL;
	}
	}
|
	variable_declaration_list
	{
	if (NOT_ONLY_PARSE)
	{
		CHECK_INVARIANT(($1 != NULL), "Declaration statement list cannot be null here");

		$$ = $1;
	}
	}
;

variable_declaration_list:
	variable_declaration
	{
	if (NOT_ONLY_PARSE)
	{
		Symbol_Table_Entry * decl_stmt = $1;

		CHECK_INVARIANT((decl_stmt != NULL), "Non-terminal declaration statement cannot be null");

		string decl_name = decl_stmt->get_variable_name();
		CHECK_INPUT ((program_object.variable_in_proc_map_check(decl_name) == false),
				"Variable name cannot be same as the procedure name", get_line_number());

		if (current_procedure != NULL)
		{
			CHECK_INPUT((current_procedure->get_proc_name() != decl_name),
				"Variable name cannot be same as procedure name", get_line_number());
		}

		Symbol_Table * decl_list = new Symbol_Table();
		decl_list->push_symbol(decl_stmt);

		$$ = decl_list;
	}
	}
|
	variable_declaration_list variable_declaration
	{
	if (NOT_ONLY_PARSE)
	{
		// if declaration is local then no need to check in global list
		// if declaration is global then this list is global list

		Symbol_Table_Entry * decl_stmt = $2;
		Symbol_Table * decl_list = $1;

		CHECK_INVARIANT((decl_stmt != NULL), "The declaration statement cannot be null");
		CHECK_INVARIANT((decl_list != NULL), "The declaration statement list cannot be null");

		string decl_name = decl_stmt->get_variable_name();
		CHECK_INPUT((program_object.variable_in_proc_map_check(decl_name) == false),
			"Procedure name cannot be same as the variable name", get_line_number());
		if (current_procedure != NULL)
		{
			CHECK_INPUT((current_procedure->get_proc_name() != decl_name),
				"Variable name cannot be same as procedure name", get_line_number());
		}

		CHECK_INPUT((decl_list->variable_in_symbol_list_check(decl_name) == false), 
				"Variable is declared twice", get_line_number());

		decl_list->push_symbol(decl_stmt);
		$$ = decl_list;
	}
	}
;

variable_declaration:
	declaration ';'
	{
	if (NOT_ONLY_PARSE)
	{
		pair<Data_Type, string> * decl_stmt = $1;

		CHECK_INVARIANT((decl_stmt != NULL), "Declaration cannot be null");

		Data_Type type = decl_stmt->first;
		string decl_name = decl_stmt->second;

		Symbol_Table_Entry * decl_entry = new Symbol_Table_Entry(decl_name, type, get_line_number());

		$$ = decl_entry;

	}
	}
;

declaration:
	INTEGER NAME
	{
	if (NOT_ONLY_PARSE)
	{
		CHECK_INVARIANT(($2 != NULL), "Name cannot be null");

		string name = *$2;
		Data_Type type = int_data_type;

		pair<Data_Type, string> * declar = new pair<Data_Type, string>(type, name);

		$$ = declar;
	}
	}
;

basic_block_list:
	basic_block_list basic_block
	{
	if (NOT_ONLY_PARSE)
	{
		list<Basic_Block *> * bb_list = $1;
		Basic_Block * bb = $2;

		CHECK_INVARIANT((bb_list != NULL), "New basic block cannot be null");
		CHECK_INVARIANT((bb != NULL), "Basic block cannot be null");

		bb_strictly_increasing_order_check(bb_list, bb->get_bb_number());

		bb_list->push_back($2);
		$$ = bb_list;
	}
	}
|
	basic_block
	{
	if (NOT_ONLY_PARSE)
	{
		Basic_Block * bb = $1;

		CHECK_INVARIANT((bb != NULL), "Basic block cannot be null");

		list<Basic_Block *> * bb_list = new list<Basic_Block *>;
		bb_list->push_back(bb);

		$$ = bb_list;
	}
	}
;

basic_block:
	BBNUM ':' executable_statement_list
	{
	if (NOT_ONLY_PARSE)
	{
		int bb_number = $1;
		list<Ast *> * exe_stmt = $3;

		CHECK_INPUT((bb_number >= 2), "Illegal basic block lable", get_line_number());

		Basic_Block * bb = new Basic_Block(bb_number, get_line_number());

		if (exe_stmt != NULL)
			bb->set_ast_list(*exe_stmt);
		else
		{
			list<Ast *> * ast_list = new list<Ast *>;
			bb->set_ast_list(*ast_list);
		}

		$$ = bb;
	}
	}
;

executable_statement_list:
	assignment_statement_list
	{
	if (NOT_ONLY_PARSE)
	{
		$$ = $1;
	}
	}
|
	assignment_statement_list RETURN ';'
	{
	if (NOT_ONLY_PARSE)
	{
		list<Ast *> * assign_list = $1;
		Ast * ret = new Return_Ast(get_line_number());
		list<Ast *> * exe_list = NULL;

		if (assign_list)
			exe_list = assign_list;

		else
			exe_list = new list<Ast *>;

		exe_list->push_back(ret);

		$$ = exe_list;
	}
	}
|	assignment_statement_list goto_statement ';'
	{
	
		if (NOT_ONLY_PARSE)
	{

		if ($1 != NULL)
			$$ = $1;

		else
			$$ = new list<Ast *>;

		$$->push_back($2);
		}
	}
|
	assignment_statement_list if_statement
	{
		if (NOT_ONLY_PARSE)
	{
		
		if ($1 != NULL)
			$$ = $1;

		else
			$$ = new list<Ast *>;

		$$->push_back($2);
		}
	}
;

assignment_statement_list:
	{
	if (NOT_ONLY_PARSE)
	{
		$$ = NULL;
	}
	}
|
	assignment_statement_list assignment_statement
	{
	if (NOT_ONLY_PARSE)
	{
		list<Ast *> * assign_list = $1;
		Ast * assign_stmt = $2;
		list<Ast *> * assign_list_new = NULL;

		CHECK_INVARIANT((assign_stmt != NULL), "Assignment statement cannot be null");

		if (assign_list == NULL)
			assign_list_new = new list<Ast *>;

		else
			assign_list_new = assign_list;

		assign_list_new->push_back(assign_stmt);

		$$ = assign_list_new;
	}
	}
;

assignment_statement:
	variable ASSIGN_OP variable ';'
	{
	if (NOT_ONLY_PARSE)
	{
		CHECK_INVARIANT((($1 != NULL) && ($3 != NULL)), "lhs/rhs cannot be null");

		Ast * lhs = $1;
		Ast * rhs = $3;

		Ast * assign = new Assignment_Ast(lhs, rhs, get_line_number());

		assign->check_ast();

		$$ = assign;
	}
	}
|
	variable ASSIGN_OP constant ';'
	{
	if (NOT_ONLY_PARSE)
	{
		CHECK_INVARIANT((($1 != NULL) && ($3 != NULL)), "lhs/rhs cannot be null");

		Ast * lhs = $1;
		Ast * rhs = $3;

		Ast * assign = new Assignment_Ast(lhs, rhs, get_line_number());

		assign->check_ast();

		$$ = assign;
	}
	}
|
	variable ASSIGN_OP h_comparison_expr ';'
	{
	if (NOT_ONLY_PARSE)
	{
		Ast * assign = new Assignment_Ast($1, $3,get_line_number());

		assign->check_ast();
		$$ = assign;
	}
	}
|
	variable ASSIGN_OP comparison_expr ';'
	{
	if (NOT_ONLY_PARSE)
	{
		Ast * assign = new Assignment_Ast($1, $3,get_line_number());
		assign->check_ast();
		$$ = assign;
	}
	}
;

if_statement:
	IF '(' h_comparison_expr ')' GOTO BBNUM ';' ELSE GOTO BBNUM ';'{
		
		if (NOT_ONLY_PARSE)
	{
		bb_requested.push_back($6);
		bb_requested.push_back($10);
		$$ = new If_Ast($3,$6,$10,get_line_number());
		}
	}
|
	IF '(' comparison_expr ')' GOTO BBNUM ';' ELSE GOTO BBNUM ';'{
	
		if (NOT_ONLY_PARSE)
	{
		bb_requested.push_back($6);
		bb_requested.push_back($10);
		$$ = new If_Ast($3,$6,$10,get_line_number());
		}
	}
|	IF '(' var_const ')' GOTO BBNUM ';' ELSE GOTO BBNUM ';'{
	
		if (NOT_ONLY_PARSE)
	{
		bb_requested.push_back($6);
		bb_requested.push_back($10);
		$$ = new If_Ast($3,$6,$10,get_line_number());
		}
	}
;

goto_statement
:	GOTO BBNUM {
		
		if (NOT_ONLY_PARSE)
	{
		$$ = new Goto_Ast($2,get_line_number());
		bb_requested.push_back($2);
		}
	}
;

h_comparison_expr
:	var_const equality_op var_const 	{
		if (NOT_ONLY_PARSE)
	{
		$$ = new Comparison_Ast($1,$2,$3,get_line_number());
		int line = get_line_number();
		$$->check_ast();
		}
	}
|	var_const equality_op comparison_expr 	{
		if (NOT_ONLY_PARSE)
	{
		$$ = new Comparison_Ast($1,$2,$3,get_line_number());
		int line = get_line_number();
		$$->check_ast();
		}
	}
|	comparison_expr equality_op var_const 	{
		if (NOT_ONLY_PARSE)
	{
		$$ = new Comparison_Ast($1,$2,$3,get_line_number());
		int line = get_line_number();
		$$->check_ast();
		}
	}
|	comparison_expr equality_op comparison_expr 	{
		if (NOT_ONLY_PARSE)
	{
		$$ = new Comparison_Ast($1,$2,$3,get_line_number());
		int line = get_line_number();
		$$->check_ast();
		}
	}
|	h_comparison_expr equality_op comparison_expr 	{
		if (NOT_ONLY_PARSE)
	{
		$$ = new Comparison_Ast($1,$2,$3,get_line_number());
		int line = get_line_number();
		$$->check_ast();
		}
	}
|	h_comparison_expr equality_op var_const {
		if (NOT_ONLY_PARSE)
	{
		$$ = new Comparison_Ast($1,$2,$3,get_line_number());
		int line = get_line_number();
		$$->check_ast();
		}
	}
;


comparison_expr
: var_const comparison_op var_const {
	if (NOT_ONLY_PARSE)
	{
	$$ = new Comparison_Ast($1,$2,$3,get_line_number());
	int line = get_line_number();
	$$->check_ast();
	}
}
| comparison_expr comparison_op var_const {
	if (NOT_ONLY_PARSE)
	{
	$$ = new Comparison_Ast($1,$2,$3,get_line_number());
	int line = get_line_number();
	$$->check_ast();
	}
}
;

var_const:
	var_const_plain{
		if (NOT_ONLY_PARSE)
	{
		$$ = $1;
		}
	}
;


var_const_plain
:	variable {
	if (NOT_ONLY_PARSE)
	{
	$$ = $1;
	}
}
|	constant {
	if (NOT_ONLY_PARSE)
	{
	$$ = $1;
	}
}
| '(' all_expr ')' {
	if (NOT_ONLY_PARSE)
	{
	$$ = $2;
	}
}
| '(' var_const ')' {
	if (NOT_ONLY_PARSE)
	{
	$$ = $2;
	}
}
;

all_expr
:	comparison_expr {
		if (NOT_ONLY_PARSE)
	{
		$$ = $1;
		}
	}
|	h_comparison_expr {
		if (NOT_ONLY_PARSE)
	{
		$$ = $1;
		}
	}
;

variable:
	NAME
	{
	if (NOT_ONLY_PARSE)
	{
		Symbol_Table_Entry * var_table_entry;

		CHECK_INVARIANT(($1 != NULL), "Variable name cannot be null");

		string var_name = *$1;

		if (current_procedure->variable_in_symbol_list_check(var_name) == true)
			 var_table_entry = &(current_procedure->get_symbol_table_entry(var_name));

		else if (program_object.variable_in_symbol_list_check(var_name) == true)
			var_table_entry = &(program_object.get_symbol_table_entry(var_name));

		else
			CHECK_INVARIANT(CONTROL_SHOULD_NOT_REACH, "Variable has not been declared");

		Ast * name_ast = new Name_Ast(var_name, *var_table_entry, get_line_number());

		$$ = name_ast;
	}
	}
;

constant:
	INTEGER_NUMBER
	{
	if (NOT_ONLY_PARSE)
	{
		int num = $1;

		Ast * num_ast = new Number_Ast<int>(num, int_data_type, get_line_number());

		$$ = num_ast;
	}
	}
;

equality_op
:	NE	{
		//if
		$$ = NE_OP; 
		//end
	}
|	EQ	{
		//if
		$$ = EQ_OP; 
		//end
	}
;

comparison_op
:	GE	{
		//if
		$$ = GE_OP; 
		//end
	}
|	LE	{
		//if
		$$ = LE_OP; 
		//end
	}
|	LT	{
		//if
		$$ = LT_OP; 
		//end
	}
|	GT	{
		//if
		$$ = GT_OP; 
		//end
	}
;