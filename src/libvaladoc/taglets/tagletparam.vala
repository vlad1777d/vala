/* taglet.vala
 *
 * Copyright (C) 2008-2009 Didier Villevalois
 * Copyright (C) 2008-2012 Florian Brosch
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 * Author:
 * 	Didier 'Ptitjes Villevalois <ptitjes@free.fr>
 */

using Valadoc.Content;
using Gee;


public class Valadoc.Taglets.Param : InlineContent, Taglet, Block {
	public string parameter_name { internal set; get; }

	public weak Api.Symbol? parameter { private set; get; }

	public int position { private set; get; default = -1; }

	public Rule? get_parser_rule (Rule run_rule) {
		return Rule.seq ({
			Rule.option ({ Rule.many ({ TokenType.SPACE }) }),
			TokenType.any_word ().action ((token) => { parameter_name = token.to_string (); }),
			run_rule
		});
	}

	public override void check (Api.Tree api_root, Api.Node container, string file_path, ErrorReporter reporter, Settings settings) {
		// Check for the existence of such a parameter
		unowned string? implicit_return_array_length = null;
		bool is_implicit = false;
		this.parameter = null;

		if (container is Api.Callable) {
			implicit_return_array_length = ((Api.Callable) container).implicit_array_length_cparameter_name;
		} else {
			reporter.simple_warning ("%s: %s: @param: warning: @param used outside method/delegate/signal context", file_path, container.get_full_name ());
			base.check (api_root, container, file_path, reporter, settings);
			return ;
		}


		if (parameter_name == "...") {
			Gee.List<Api.Node> params = container.get_children_by_type (Api.NodeType.FORMAL_PARAMETER, false);
			foreach (Api.Node param in params) {
				if (((Api.FormalParameter) param).ellipsis) {
					this.parameter = (Api.Symbol) param;
					this.position = params.size - 1;
					break;
				}
			}
		} else {
			Gee.List<Api.Node> params = container.get_children_by_types ({Api.NodeType.FORMAL_PARAMETER, Api.NodeType.TYPE_PARAMETER}, false);
			int pos = 0;

			foreach (Api.Node param in params) {
				if (param.name == parameter_name) {
					this.parameter = (Api.Symbol) param;
					this.position = pos;
					break;
				}

				Api.FormalParameter formalparam = param as Api.FormalParameter;
				if (formalparam != null && (formalparam.implicit_array_length_cparameter_name == parameter_name || formalparam.implicit_closure_cparameter_name == parameter_name || formalparam.implicit_destroy_cparameter_name == parameter_name)) {
					is_implicit = true;
					break;
				}

				pos++;
			}

			if (this.parameter == null && (parameter_name == "error" && container.has_children ({Api.NodeType.ERROR_DOMAIN, Api.NodeType.CLASS})
			   || parameter_name == implicit_return_array_length)) {
				is_implicit = true;
			}
		}

		if (this.parameter == null) {
			if (is_implicit) {
				reporter.simple_note ("%s: %s: @param: warning: Implicit parameter `%s' exposed in documentation", file_path, container.get_full_name (), parameter_name);
			} else {
				reporter.simple_warning ("%s: %s: @param: warning: Unknown parameter `%s'", file_path, container.get_full_name (), parameter_name);
			}
		}

		base.check (api_root, container, file_path, reporter, settings);
	}

	public override void accept (ContentVisitor visitor) {
		visitor.visit_taglet (this);
	}

	public Gee.List<ContentElement>? get_inheritable_documentation () {
		return content;
	}

	public bool inheritable (Taglet taglet) {
		if (taglet is Taglets.Param == false) {
			return false;
		}

		Taglets.Param t = (Taglets.Param) taglet;
		return (parameter == t.parameter || parameter_name == t.parameter_name);
	}

	public override ContentElement copy (ContentElement? new_parent = null) {
		Param param = new Param ();
		param.parent = new_parent;

		param.parameter_name = parameter_name;
		param.parameter = parameter;
		param.position = position;

		foreach (Inline element in content) {
			Inline copy = element.copy (param) as Inline;
			param.content.add (copy);
		}

		return param;
	}
}
