import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { ArrowRight, Code, Palette, Zap } from "lucide-react"
import Link from "next/link"

export default function HomePage() {
  return (
    <div className="container mx-auto px-4 py-8">
      {/* Section Hero */}
      <section className="text-center py-20">
        <h1 className="text-4xl md:text-6xl font-bold mb-6 bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
          Bienvenue sur Mon Projet Next.js
        </h1>
        <p className="text-xl text-muted-foreground mb-8 max-w-2xl mx-auto">
          Une application moderne construite avec Next.js 15, TypeScript, et Tailwind CSS. Découvrez les dernières
          fonctionnalités et les meilleures pratiques.
        </p>
        <div className="flex gap-4 justify-center flex-wrap">
          <Button size="lg" asChild>
            <Link href="/about">
              En savoir plus
              <ArrowRight className="ml-2 h-4 w-4" />
            </Link>
          </Button>
          <Button variant="outline" size="lg" asChild>
            <Link href="/contact">Nous contacter</Link>
          </Button>
        </div>
      </section>

      {/* Section Fonctionnalités */}
      <section className="py-20">
        <h2 className="text-3xl font-bold text-center mb-12">Fonctionnalités Principales</h2>
        <div className="grid md:grid-cols-3 gap-8">
          <Card>
            <CardHeader>
              <div className="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center mb-4">
                <Code className="h-6 w-6 text-blue-600" />
              </div>
              <CardTitle>Développement Moderne</CardTitle>
              <CardDescription>
                Utilise les dernières technologies : Next.js 15, TypeScript, et l'App Router
              </CardDescription>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground">
                Profitez des Server Components, du streaming, et des optimisations automatiques pour une expérience de
                développement exceptionnelle.
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <div className="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center mb-4">
                <Zap className="h-6 w-6 text-green-600" />
              </div>
              <CardTitle>Performance Optimale</CardTitle>
              <CardDescription>Optimisations automatiques pour des temps de chargement ultra-rapides</CardDescription>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground">
                Code splitting automatique, optimisation des images, et mise en cache intelligente pour des performances
                maximales.
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <div className="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center mb-4">
                <Palette className="h-6 w-6 text-purple-600" />
              </div>
              <CardTitle>Design Élégant</CardTitle>
              <CardDescription>Interface utilisateur moderne avec Tailwind CSS et shadcn/ui</CardDescription>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground">
                Composants réutilisables, design responsive, et thème sombre/clair pour une expérience utilisateur
                exceptionnelle.
              </p>
            </CardContent>
          </Card>
        </div>
      </section>

      {/* Section CTA */}
      <section className="py-20 text-center">
        <div className="bg-gradient-to-r from-blue-50 to-purple-50 rounded-2xl p-12">
          <h2 className="text-3xl font-bold mb-4">Prêt à commencer ?</h2>
          <p className="text-lg text-muted-foreground mb-8 max-w-2xl mx-auto">
            Explorez notre projet et découvrez comment nous pouvons vous aider à créer des applications web
            exceptionnelles.
          </p>
          <Button size="lg" asChild>
            <Link href="/contact">
              Commencer maintenant
              <ArrowRight className="ml-2 h-4 w-4" />
            </Link>
          </Button>
        </div>
      </section>
    </div>
  )
}
