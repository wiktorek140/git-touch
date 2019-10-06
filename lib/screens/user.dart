import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:git_touch/models/theme.dart';
import 'package:git_touch/scaffolds/refresh_stateful.dart';
import 'package:git_touch/screens/repositories.dart';
import 'package:git_touch/widgets/action_entry.dart';
import 'package:git_touch/widgets/app_bar_title.dart';
import 'package:git_touch/widgets/table_view.dart';
import 'package:git_touch/widgets/text_contains_organization.dart';
import 'package:git_touch/widgets/user_item.dart';
import 'package:primer/primer.dart';
import 'package:github_contributions/github_contributions.dart';
import 'package:git_touch/models/auth.dart';
import 'package:provider/provider.dart';
import '../widgets/entry_item.dart';
import 'package:git_touch/widgets/repository_item.dart';
import 'package:git_touch/widgets/action_button.dart';
import '../screens/users.dart';
import '../screens/settings.dart';
import '../utils/utils.dart';

class UserScreen extends StatelessWidget {
  final String login;
  final bool isMe;

  UserScreen(this.login, {this.isMe = false});

  Future query(BuildContext context) async {
    var data = await Provider.of<AuthModel>(context).query('''
{
  user(login: "$login") {
    $userGqlChunk
    company
    location
    email
    websiteUrl
    starredRepositories {
      totalCount
    }
    followers {
      totalCount
    }
    following {
      totalCount
    }
    repositories(first: 6, ownerAffiliations: OWNER, orderBy: {field: STARGAZERS, direction: DESC}) {
      totalCount
      nodes {
        $repoChunk
      }
    }
    pinnedItems(first: 6) {
      nodes {
        ... on Repository {
          $repoChunk
        }
      }
    }
    viewerCanFollow
    viewerIsFollowing
    url
  }
}
''');
    return data['user'];
  }

  Widget _buildContributions(List<ContributionsInfo> contributions) {
    final row = Row(
      children: <Widget>[],
      crossAxisAlignment: CrossAxisAlignment.start,
    );
    Column column;

    contributions.asMap().forEach((i, v) {
      var rect = SizedBox(
        width: 10,
        height: 10,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: convertColor(v.color),
          ),
        ),
      );

      if (i % 7 == 0) {
        column = Column(children: <Widget>[rect]);
        row.children.add(column);
        row.children.add(SizedBox(width: 3));
      } else {
        column.children.add(SizedBox(height: 3));
        column.children.add(rect);
      }
    });

    return Container(
      color: Colors.white,
      padding: CommonStyle.padding,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: row,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshStatefulScaffold(
      fetchData: () {
        return Future.wait(
          [query(context), getContributions(login)],
        );
      },
      title: AppBarTitle('User'),
      actionBuilder: (payload) {
        var data = payload.data;
        if (isMe) {
          return ActionEntry(
            iconData: Icons.settings,
            onTap: () {
              Provider.of<ThemeModel>(context).pushRoute(
                  context, (_) => SettingsScreen(),
                  fullscreenDialog: true);
            },
          );
        } else {
          return ActionButton(
            title: 'User Actions',
            items: [
              if (data != null && data[0]['viewerCanFollow'])
                ActionItem(
                  text: data[0]['viewerIsFollowing'] ? 'Unfollow' : 'Follow',
                  onPress: () async {
                    if (data[0]['viewerIsFollowing']) {
                      await Provider.of<AuthModel>(context)
                          .deleteWithCredentials('/user/following/$login');
                      data[0]['viewerIsFollowing'] = false;
                    } else {
                      Provider.of<AuthModel>(context)
                          .putWithCredentials('/user/following/$login');
                      data[0]['viewerIsFollowing'] = true;
                    }
                  },
                ),
              if (data != null) ...[
                ActionItem.share(data[0]['url']),
                ActionItem.launch(data[0]['url']),
              ],
            ],
          );
        }
      },
      bodyBuilder: (payload) {
        var data = payload.data[0];
        var contributions = payload.data[1] as List<ContributionsInfo>;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            UserItem.fromData(data, inUserScreen: true),
            CommonStyle.border,
            Row(children: <Widget>[
              EntryItem(
                count: data['repositories']['totalCount'],
                text: 'Repositories',
                screenBuilder: (context) => RepositoriesScreen(login),
              ),
              EntryItem(
                count: data['starredRepositories']['totalCount'],
                text: 'Stars',
                screenBuilder: (context) => RepositoriesScreen.stars(login),
              ),
              EntryItem(
                count: data['followers']['totalCount'],
                text: 'Followers',
                screenBuilder: (context) => UsersScreen.followers(login),
              ),
              EntryItem(
                count: data['following']['totalCount'],
                text: 'Following',
                screenBuilder: (context) => UsersScreen.following(login),
              ),
            ]),
            CommonStyle.verticalGap,
            _buildContributions(contributions),
            CommonStyle.verticalGap,
            TableView(
              hasIcon: true,
              items: [
                if (isNotNullOrEmpty(data['company']))
                  TableViewItem(
                    leftIconData: Octicons.organization,
                    text: TextContainsOrganization(data['company'],
                        style: TextStyle(
                            fontSize: 16, color: PrimerColors.gray900),
                        overflow: TextOverflow.ellipsis),
                  ),
                if (isNotNullOrEmpty(data['location']))
                  TableViewItem(
                    leftIconData: Octicons.location,
                    text: Text(data['location']),
                    onTap: () {
                      launchUrl('https://www.google.com/maps/place/' +
                          (data['location'] as String)
                              .replaceAll(RegExp(r'\s+'), ''));
                    },
                  ),
                if (isNotNullOrEmpty(data['email']))
                  TableViewItem(
                    leftIconData: Octicons.mail,
                    text: Text(data['email']),
                    onTap: () {
                      launchUrl('mailto:' + data['email']);
                    },
                  ),
                if (isNotNullOrEmpty(data['websiteUrl']))
                  TableViewItem(
                    leftIconData: Octicons.link,
                    text: Text(data['websiteUrl']),
                    onTap: () {
                      var url = data['websiteUrl'] as String;
                      if (!url.startsWith('http')) {
                        url = 'http://$url';
                      }
                      launchUrl(url);
                    },
                  ),
              ],
            ),
            ...buildPinnedItems(
                data['pinnedItems']['nodes'], data['repositories']['nodes']),
            CommonStyle.verticalGap,
          ],
        );
      },
    );
  }
}
