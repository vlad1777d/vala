/* valagerrormodule.vala
 *
 * Copyright (C) 2008-2009  Jürg Billeter
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.

 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.

 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 * Author:
 *	Jürg Billeter <j@bitron.ch>
 *	Thijs Vermeir <thijsvermeir@gmail.com>
 */

using GLib;
using Gee;

internal class Vala.GErrorModule : CCodeDelegateModule {
	private int current_try_id = 0;
	private int next_try_id = 0;

	public GErrorModule (CCodeGenerator codegen, CCodeModule? next) {
		base (codegen, next);
	}

	public override void generate_error_domain_declaration (ErrorDomain edomain, CCodeDeclarationSpace decl_space) {
		if (decl_space.add_symbol_declaration (edomain, edomain.get_cname ())) {
			return;
		}

		var cenum = new CCodeEnum (edomain.get_cname ());

		foreach (ErrorCode ecode in edomain.get_codes ()) {
			if (ecode.value == null) {
				cenum.add_value (new CCodeEnumValue (ecode.get_cname ()));
			} else {
				ecode.value.accept (codegen);
				cenum.add_value (new CCodeEnumValue (ecode.get_cname (), (CCodeExpression) ecode.value.ccodenode));
			}
		}

		if (edomain.source_reference.comment != null) {
			decl_space.add_type_definition (new CCodeComment (edomain.source_reference.comment));
		}
		decl_space.add_type_definition (cenum);

		string quark_fun_name = edomain.get_lower_case_cprefix () + "quark";

		var error_domain_define = new CCodeMacroReplacement (edomain.get_upper_case_cname (), quark_fun_name + " ()");
		decl_space.add_type_definition (error_domain_define);

		var cquark_fun = new CCodeFunction (quark_fun_name, gquark_type.data_type.get_cname ());

		decl_space.add_type_member_declaration (cquark_fun);
	}

	public override void visit_error_domain (ErrorDomain edomain) {
		generate_error_domain_declaration (edomain, source_declarations);

		string quark_fun_name = edomain.get_lower_case_cprefix () + "quark";

		var cquark_fun = new CCodeFunction (quark_fun_name, gquark_type.data_type.get_cname ());
		var cquark_block = new CCodeBlock ();

		var cquark_call = new CCodeFunctionCall (new CCodeIdentifier ("g_quark_from_static_string"));
		cquark_call.add_argument (new CCodeConstant ("\"" + edomain.get_lower_case_cname () + "-quark\""));

		cquark_block.add_statement (new CCodeReturnStatement (cquark_call));

		cquark_fun.block = cquark_block;
		source_type_member_definition.append (cquark_fun);
	}

	public override void visit_throw_statement (ThrowStatement stmt) {
		stmt.accept_children (codegen);

		var cfrag = new CCodeFragment ();

		// method will fail
		current_method_inner_error = true;
		var cassign = new CCodeAssignment (get_variable_cexpression ("inner_error"), (CCodeExpression) stmt.error_expression.ccodenode);
		cfrag.append (new CCodeExpressionStatement (cassign));

		head.add_simple_check (stmt, cfrag);

		stmt.ccodenode = cfrag;

		create_temp_decl (stmt, stmt.error_expression.temp_vars);
	}

	public virtual CCodeStatement return_with_exception (CCodeExpression error_expr)
	{
		var cpropagate = new CCodeFunctionCall (new CCodeIdentifier ("g_propagate_error"));
		cpropagate.add_argument (get_variable_cexpression ("error"));
		cpropagate.add_argument (error_expr);

		var cerror_block = new CCodeBlock ();
		cerror_block.add_statement (new CCodeExpressionStatement (cpropagate));

		// free local variables
		var free_frag = new CCodeFragment ();
		append_local_free (current_symbol, free_frag, false);
		cerror_block.add_statement (free_frag);

		if (current_return_type is VoidType) {
			cerror_block.add_statement (new CCodeReturnStatement ());
		} else {
			cerror_block.add_statement (new CCodeReturnStatement (default_value_for_type (current_return_type, false)));
		}

		return cerror_block;
	}

	CCodeStatement uncaught_error_statement (CCodeExpression inner_error) {
		var cerror_block = new CCodeBlock ();

		// free local variables
		var free_frag = new CCodeFragment ();
		append_local_free (current_symbol, free_frag, false);
		cerror_block.add_statement (free_frag);

		var ccritical = new CCodeFunctionCall (new CCodeIdentifier ("g_critical"));
		ccritical.add_argument (new CCodeConstant ("\"file %s: line %d: uncaught error: %s\""));
		ccritical.add_argument (new CCodeConstant ("__FILE__"));
		ccritical.add_argument (new CCodeConstant ("__LINE__"));
		ccritical.add_argument (new CCodeMemberAccess.pointer (inner_error, "message"));

		var cclear = new CCodeFunctionCall (new CCodeIdentifier ("g_clear_error"));
		cclear.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, inner_error));

		var cprint_frag = new CCodeFragment ();
		cprint_frag.append (new CCodeExpressionStatement (ccritical));
		cprint_frag.append (new CCodeExpressionStatement (cclear));

		// print critical message
		cerror_block.add_statement (cprint_frag);

		if (current_return_type is VoidType) {
			cerror_block.add_statement (new CCodeReturnStatement ());
		} else if (current_return_type != null) {
			cerror_block.add_statement (new CCodeReturnStatement (default_value_for_type (current_return_type, false)));
		}

		return cerror_block;
	}

	public override void add_simple_check (CodeNode node, CCodeFragment cfrag) {
		current_method_inner_error = true;

		var inner_error = get_variable_cexpression ("inner_error");

		CCodeStatement cerror_handler = null;

		if (current_try != null) {
			// surrounding try found
			var cerror_block = new CCodeBlock ();

			// free local variables
			var free_frag = new CCodeFragment ();
			append_error_free (current_symbol, free_frag, current_try);
			cerror_block.add_statement (free_frag);

			foreach (CatchClause clause in current_try.get_catch_clauses ()) {
				// go to catch clause if error domain matches
				var cgoto_stmt = new CCodeGotoStatement (clause.clabel_name);

				if (clause.error_type.equals (gerror_type)) {
					// general catch clause, this should be the last one
					cerror_block.add_statement (cgoto_stmt);
					break;
				} else {
					var catch_type = clause.error_type as ErrorType;
					var cgoto_block = new CCodeBlock ();
					cgoto_block.add_statement (cgoto_stmt);

					if (catch_type.error_code != null) {
						/* catch clause specifies a specific error code */
						var error_match = new CCodeFunctionCall (new CCodeIdentifier ("g_error_matches"));
						error_match.add_argument (inner_error);
						error_match.add_argument (new CCodeIdentifier (catch_type.data_type.get_upper_case_cname ()));
						error_match.add_argument (new CCodeIdentifier (catch_type.error_code.get_cname ()));

						cerror_block.add_statement (new CCodeIfStatement (error_match, cgoto_block));
					} else {
						/* catch clause specifies a full error domain */
						var ccond = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY,
								new CCodeMemberAccess.pointer (inner_error, "domain"), new CCodeIdentifier
								(clause.error_type.data_type.get_upper_case_cname ()));

						cerror_block.add_statement (new CCodeIfStatement (ccond, cgoto_block));
					}
				}
			}

			// go to finally clause if no catch clause matches
			cerror_block.add_statement (new CCodeGotoStatement ("__finally%d".printf (current_try_id)));

			cerror_handler = cerror_block;
		} else if (current_method != null && current_method.get_error_types ().size > 0) {
			// current method can fail, propagate error
			CCodeBinaryExpression ccond = null;

			foreach (DataType error_type in current_method.get_error_types ()) {
				// If GLib.Error is allowed we propagate everything
				if (error_type.equals (gerror_type)) {
					ccond = null;
					break;
				}

				// Check the allowed error domains to propagate
				var domain_check = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, new CCodeMemberAccess.pointer
					(inner_error, "domain"), new CCodeIdentifier (error_type.data_type.get_upper_case_cname ()));
				if (ccond == null) {
					ccond = domain_check;
				} else {
					ccond = new CCodeBinaryExpression (CCodeBinaryOperator.OR, ccond, domain_check);
				}
			}

			if (ccond == null) {
				cerror_handler = return_with_exception (inner_error);
			} else {
				var cerror_block = new CCodeBlock ();
				cerror_block.add_statement (new CCodeIfStatement (ccond,
					return_with_exception (inner_error),
					uncaught_error_statement (inner_error)));
				cerror_handler = cerror_block;
			}
		} else {
			cerror_handler = uncaught_error_statement (inner_error);
		}
		
		var ccond = new CCodeBinaryExpression (CCodeBinaryOperator.INEQUALITY, inner_error, new CCodeConstant ("NULL"));
		cfrag.append (new CCodeIfStatement (ccond, cerror_handler));
	}

	public override void visit_try_statement (TryStatement stmt) {
		int this_try_id = next_try_id++;

		var old_try = current_try;
		var old_try_id = current_try_id;
		current_try = stmt;
		current_try_id = this_try_id;

		foreach (CatchClause clause in stmt.get_catch_clauses ()) {
			clause.clabel_name = "__catch%d_%s".printf (this_try_id, clause.error_type.get_lower_case_cname ());
		}

		if (stmt.finally_body != null) {
			stmt.finally_body.accept (codegen);
		}

		stmt.body.accept (codegen);

		current_try = old_try;
		current_try_id = old_try_id;

		foreach (CatchClause clause in stmt.get_catch_clauses ()) {
			clause.accept (codegen);
		}

		if (stmt.finally_body != null) {
			stmt.finally_body.accept (codegen);
		}

		var cfrag = new CCodeFragment ();
		cfrag.append (stmt.body.ccodenode);

		foreach (CatchClause clause in stmt.get_catch_clauses ()) {
			cfrag.append (new CCodeGotoStatement ("__finally%d".printf (this_try_id)));

			cfrag.append (clause.ccodenode);
		}

		cfrag.append (new CCodeLabel ("__finally%d".printf (this_try_id)));
		if (stmt.finally_body != null) {
			cfrag.append (stmt.finally_body.ccodenode);
		}

		// check for errors not handled by this try statement
		// may be handled by outer try statements or propagated
		add_simple_check (stmt, cfrag);

		stmt.ccodenode = cfrag;
	}

	public override void visit_catch_clause (CatchClause clause) {
		if (clause.error_variable != null) {
			clause.error_variable.active = true;
		}

		current_method_inner_error = true;

		clause.accept_children (codegen);

		var cfrag = new CCodeFragment ();
		cfrag.append (new CCodeLabel (clause.clabel_name));

		var cblock = new CCodeBlock ();

		string variable_name = clause.variable_name;
		if (variable_name == null) {
			variable_name = "__err";
		}

		if (current_method != null && current_method.coroutine) {
			closure_struct.add_field ("GError *", variable_name);
			cblock.add_statement (new CCodeExpressionStatement (new CCodeAssignment (get_variable_cexpression (variable_name), get_variable_cexpression ("inner_error"))));
		} else {
			var cdecl = new CCodeDeclaration ("GError *");
			cdecl.add_declarator (new CCodeVariableDeclarator (variable_name, get_variable_cexpression ("inner_error")));
			cblock.add_statement (cdecl);
		}
		cblock.add_statement (new CCodeExpressionStatement (new CCodeAssignment (get_variable_cexpression ("inner_error"), new CCodeConstant ("NULL"))));

		cblock.add_statement (clause.body.ccodenode);

		cfrag.append (cblock);

		clause.ccodenode = cfrag;
	}
}

// vim:sw=8 noet
